defmodule Quenta.ExpenseCalculator do
  alias Quenta.Expenses.Expense

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

      amount_paid = if user.id == expense.created_by_user_id, do: total_amount, else: 0

      # Distribute remainder to first N users (where N = remainder)
      extra_cent = if index < remainder, do: 1, else: 0

      balance = personal_items + shared_per_person + extra_cent - amount_paid

      %{user: user, balance: balance}
    end)
  end

  @doc """
  Summarizes the evenly shared portion of an expense across participants.

  Returns a map with:
    - `:shared_total_cents`
    - `:per_person_cents`
    - `:remainder_cents`
    - `:participants_count`

  If `expense_items` are not preloaded on the expense, this function will preload
  them automatically to compute the shared totals.
  """
  def even_split_summary(_expense, []),
    do: %{
      shared_total_cents: 0,
      per_person_cents: 0,
      remainder_cents: 0,
      participants_count: 0
    }

  def even_split_summary(%Expense{expense_items: %Ecto.Association.NotLoaded{}} = expense, users) do
    preloaded_expense = Quenta.Repo.preload(expense, :expense_items)
    even_split_summary(preloaded_expense, users)
  end

  def even_split_summary(expense, users) do
    participants_count = length(users)
    expense_items_cents = expense.expense_items |> Enum.map(& &1.amount_cents) |> Enum.sum()
    shared_cents = expense.amount_cents - expense_items_cents
    per_person_cents = shared_cents |> div(participants_count)
    remainder_cents = rem(shared_cents, participants_count)

    %{
      shared_total_cents: shared_cents,
      per_person_cents: per_person_cents,
      remainder_cents: remainder_cents,
      participants_count: participants_count
    }
  end
end
