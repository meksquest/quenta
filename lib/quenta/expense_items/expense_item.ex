defmodule Quenta.ExpenseItems.ExpenseItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_items" do
    field :description, :string
    field :amount_cents, :integer
    field :amount_dollars, :decimal, virtual: true

    belongs_to :expense, Quenta.Expenses.Expense
    belongs_to :user, Quenta.Users.User

    timestamps()
  end

  @required_fields ~w(description amount_dollars user_id)a
  @fields @required_fields ++ ~w(expense_id)a

  def changeset(expense_item, attrs) do
    expense_item
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> convert_dollars_to_cents()
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
end
