defmodule Quenta.Expenses do
  alias Quenta.Expenses.Expense
  alias Quenta.ExpenseCalculator
  alias Quenta.PubSub
  alias Quenta.Repo

  import Ecto.Query, only: [from: 2]

  def change_expense(expense, attrs) do
    expense |> Expense.changeset(attrs)
  end

  def create_expense(attrs) do
    case %Expense{} |> Expense.changeset(attrs) |> Repo.insert() do
      {:ok, expense} ->
        PubSub.broadcast_expense_added(expense)
        {:ok, expense}

      res ->
        res
    end
  end

  def list_expenses(opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])

    Expense
    |> from(order_by: [desc: :date, desc: :inserted_at, desc: :id])
    |> Repo.all()
    |> Repo.preload(preloads)
  end

  def get_expense!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])
    Expense |> Repo.get!(id) |> Repo.preload(preloads)
  end

  def get_expense_for_edit!(id) do
    expense =
      get_expense!(id, preloads: [:expense_items, :expense_participants, :expense_payments])

    hydrate_amount_dollars(expense)
  end

  defp hydrate_amount_dollars(%Expense{} = expense) do
    amount_dollars = cents_to_dollars(expense.amount_cents)

    expense_items =
      Enum.map(expense.expense_items, fn item ->
        %{item | amount_dollars: cents_to_dollars(item.amount_cents)}
      end)

    expense_participants =
      Enum.map(expense.expense_participants, fn participant ->
        %{participant | share_dollars: cents_to_dollars(participant.share_cents)}
      end)

    expense_payments =
      Enum.map(expense.expense_payments, fn payment ->
        %{payment | amount_dollars: cents_to_dollars(payment.amount_cents)}
      end)

    participants_user_ids = Enum.map(expense_participants, & &1.user_id)

    paid_by_user_id =
      case expense_payments do
        [payment | _] -> payment.user_id
        _ -> nil
      end

    %{
      expense
      | amount_dollars: amount_dollars,
        expense_items: expense_items,
        expense_participants: expense_participants,
        expense_payments: expense_payments,
        participants_user_ids: participants_user_ids,
        paid_by_user_id: paid_by_user_id
    }
  end

  defp cents_to_dollars(nil), do: nil

  defp cents_to_dollars(cents) do
    cents
    |> Decimal.new()
    |> Decimal.div(100)
    |> Decimal.round(2)
  end

  @doc """
  Returns user-focused settlements per currency for a list of expenses.

  Each settlement line is expressed relative to the given user:
  - :you_owe means the user should pay the other_user
  - :owed_to_you means the other_user should pay the user
  """
  def list_user_settlements_by_currency(expenses, users, user_id) do
    expenses
    |> Enum.reduce(%{}, fn expense, totals ->
      currency_code = expense.currency_code || "USD"
      balances = ExpenseCalculator.calculate_balances(expense, expense.expense_items, users)

      Enum.reduce(balances, totals, fn %{user: user, balance: balance}, acc ->
        Map.update(
          acc,
          currency_code,
          %{user.id => %{user: user, balance: balance}},
          fn user_map ->
            Map.update(user_map, user.id, %{user: user, balance: balance}, fn existing ->
              %{existing | balance: existing.balance + balance}
            end)
          end
        )
      end)
    end)
    |> Enum.map(fn {currency_code, user_map} ->
      settlements =
        user_map
        |> Map.values()
        |> settle_balances()
        |> Enum.filter(fn settlement ->
          settlement.from.id == user_id or settlement.to.id == user_id
        end)
        |> Enum.map(fn settlement ->
          if settlement.from.id == user_id do
            %{
              direction: :you_owe,
              other_user: settlement.to,
              amount_cents: settlement.amount_cents
            }
          else
            %{
              direction: :owed_to_you,
              other_user: settlement.from,
              amount_cents: settlement.amount_cents
            }
          end
        end)

      {currency_code, settlements}
    end)
    |> Enum.reject(fn {_currency_code, settlements} -> settlements == [] end)
    |> Enum.sort_by(fn {currency_code, _} -> currency_code end)
  end

  defp settle_balances(balances) do
    debtors =
      balances
      |> Enum.filter(&(&1.balance > 0))
      |> Enum.map(&%{user: &1.user, amount: &1.balance})
      |> Enum.sort_by(& &1.user.name)

    creditors =
      balances
      |> Enum.filter(&(&1.balance < 0))
      |> Enum.map(&%{user: &1.user, amount: abs(&1.balance)})
      |> Enum.sort_by(& &1.user.name)

    settle_balances(debtors, creditors, [])
  end

  defp settle_balances([], _creditors, acc), do: Enum.reverse(acc)
  defp settle_balances(_debtors, [], acc), do: Enum.reverse(acc)

  defp settle_balances([debtor | rest_debtors], [creditor | rest_creditors], acc) do
    amount = min(debtor.amount, creditor.amount)
    settlement = %{from: debtor.user, to: creditor.user, amount_cents: amount}

    new_debtor_amount = debtor.amount - amount
    new_creditor_amount = creditor.amount - amount

    cond do
      new_debtor_amount == 0 and new_creditor_amount == 0 ->
        settle_balances(rest_debtors, rest_creditors, [settlement | acc])

      new_debtor_amount == 0 ->
        settle_balances(
          rest_debtors,
          [%{creditor | amount: new_creditor_amount} | rest_creditors],
          [settlement | acc]
        )

      new_creditor_amount == 0 ->
        settle_balances(
          [%{debtor | amount: new_debtor_amount} | rest_debtors],
          rest_creditors,
          [settlement | acc]
        )

      true ->
        settle_balances(
          [%{debtor | amount: new_debtor_amount} | rest_debtors],
          [%{creditor | amount: new_creditor_amount} | rest_creditors],
          [settlement | acc]
        )
    end
  end

  def update_expense(%Expense{} = expense, attrs) do
    expense
    |> Repo.preload([:expense_items, :expense_participants, :expense_payments])
    |> Expense.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_expense} ->
        PubSub.broadcast_expense_updated(updated_expense)
        {:ok, updated_expense}

      error ->
        error
    end
  end

  def delete_expense(%Expense{} = expense) do
    case Repo.delete(expense) do
      {:ok, deleted_expense} ->
        PubSub.broadcast_expense_deleted(deleted_expense)
        {:ok, deleted_expense}

      error ->
        error
    end
  end
end
