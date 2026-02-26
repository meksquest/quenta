defmodule Quenta.Expenses do
  alias Quenta.Expenses.Expense
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
    expense = get_expense!(id, preloads: [:expense_items])
    hydrate_amount_dollars(expense)
  end

  defp hydrate_amount_dollars(%Expense{} = expense) do
    amount_dollars = cents_to_dollars(expense.amount_cents)

    expense_items =
      Enum.map(expense.expense_items, fn item ->
        %{item | amount_dollars: cents_to_dollars(item.amount_cents)}
      end)

    %{expense | amount_dollars: amount_dollars, expense_items: expense_items}
  end

  defp cents_to_dollars(nil), do: nil

  defp cents_to_dollars(cents) do
    cents
    |> Decimal.new()
    |> Decimal.div(100)
    |> Decimal.round(2)
  end

  def update_expense(%Expense{} = expense, attrs) do
    expense
    |> Repo.preload(:expense_items)
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
