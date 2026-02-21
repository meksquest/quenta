defmodule Quenta.ExpenseCalculator do
  @doc """
  Calculates how much each user owes or is owed for a given expense.

  Returns a list of maps with :user and :balance keys.
  Positive balance means the user owes money.
  Negative balance means the user is owed money.
  """
  def calculate_balances(expense, expense_items, users) do
    total_amount = expense.amount_cents

    # Sum all personal items
    personal_total =
      expense_items
      |> Enum.map(& &1.amount_cents)
      |> Enum.sum()

    # Calculate shared amount
    shared_amount = total_amount - personal_total
    shared_per_person = div(shared_amount, length(users))
    remainder = rem(shared_amount, length(users))

    # Calculate what each person owes
    users
    |> Enum.with_index()
    |> Enum.map(fn {user, index} ->
      personal_items =
        expense_items
        |> Enum.filter(&(&1.user_id == user.id))
        |> Enum.map(& &1.amount_cents)
        |> Enum.sum()

      amount_paid = if user.id == expense.user_id, do: total_amount, else: 0

      # Distribute remainder to first N users (where N = remainder)
      extra_cent = if index < remainder, do: 1, else: 0

      balance = personal_items + shared_per_person + extra_cent - amount_paid

      %{user: user, balance: balance}
    end)
  end
end
