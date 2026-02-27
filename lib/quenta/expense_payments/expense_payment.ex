defmodule Quenta.ExpensePayments.ExpensePayment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_payments" do
    field :amount_cents, :integer

    belongs_to :expense, Quenta.Expenses.Expense
    belongs_to :user, Quenta.Users.User

    timestamps()
  end

  @required_fields ~w(expense_id user_id amount_cents)a

  def changeset(expense_payment, attrs) do
    expense_payment
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:amount_cents, greater_than: 0)
    |> assoc_constraint(:expense)
    |> assoc_constraint(:user)
  end
end
