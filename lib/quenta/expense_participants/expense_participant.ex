defmodule Quenta.ExpenseParticipants.ExpenseParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_participants" do
    field :share_cents, :integer
    field :share_dollars, :decimal, virtual: true

    belongs_to :expense, Quenta.Expenses.Expense
    belongs_to :user, Quenta.Users.User

    timestamps()
  end

  @required_fields ~w(user_id)a
  @fields ~w(expense_id user_id share_cents share_dollars)a

  def changeset(expense_participant, attrs) do
    expense_participant
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> convert_dollars_to_cents()
    |> validate_share_present()
    |> validate_number(:share_cents, greater_than_or_equal_to: 0)
    |> assoc_constraint(:expense)
    |> assoc_constraint(:user)
  end

  defp convert_dollars_to_cents(changeset) do
    case get_change(changeset, :share_dollars) do
      nil ->
        changeset

      amount ->
        put_change(changeset, :share_cents, amount |> Decimal.mult(100) |> Decimal.to_integer())
    end
  end

  defp validate_share_present(changeset) do
    case get_field(changeset, :share_cents) do
      nil -> add_error(changeset, :share_dollars, "can't be blank")
      _ -> changeset
    end
  end
end
