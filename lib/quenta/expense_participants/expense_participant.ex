defmodule Quenta.ExpenseParticipants.ExpenseParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_participants" do
    field :share_cents, :integer

    belongs_to :expense, Quenta.Expenses.Expense
    belongs_to :user, Quenta.Users.User

    timestamps()
  end

  @required_fields ~w(expense_id user_id share_cents)a

  def changeset(expense_participant, attrs) do
    expense_participant
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:share_cents, greater_than_or_equal_to: 0)
    |> assoc_constraint(:expense)
    |> assoc_constraint(:user)
  end
end
