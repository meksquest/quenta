defmodule Quenta.Expenses do
  alias Quenta.Expenses.Expense
  alias Quenta.PubSub
  alias Quenta.Repo

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
    Expense |> Repo.all() |> Repo.preload(preloads)
  end

  def get_expense!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])
    Expense |> Repo.get!(id) |> Repo.preload(preloads)
  end

  def delete_expense(%Expense{} = expense) do
    Repo.delete(expense)
  end
end
