defmodule Quenta.ExpensePayments.ExpensePayment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_payments" do
    field :amount_cents, :integer
    field :amount_dollars, :decimal, virtual: true

    belongs_to :expense, Quenta.Expenses.Expense
    belongs_to :user, Quenta.Users.User

    timestamps()
  end

  @required_fields ~w(user_id)a
  @cast_fields ~w(expense_id user_id amount_cents amount_dollars)a

  def changeset(expense_payment, attrs) do
    expense_payment
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> convert_dollars_to_cents()
    |> validate_amount_present()
    |> validate_number(:amount_cents, greater_than: 0)
    |> assoc_constraint(:expense)
    |> assoc_constraint(:user)
  end

  defp convert_dollars_to_cents(changeset) do
    case get_change(changeset, :amount_dollars) do
      nil ->
        changeset

      amount ->
        put_change(changeset, :amount_cents, amount |> Decimal.mult(100) |> Decimal.to_integer())
    end
  end

  defp validate_amount_present(changeset) do
    case get_field(changeset, :amount_cents) do
      nil -> add_error(changeset, :amount_dollars, "can't be blank")
      _ -> changeset
    end
  end
end
