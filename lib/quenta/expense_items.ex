defmodule Quenta.ExpenseItems do
  alias Quenta.Repo
  alias Quenta.ExpenseItems.ExpenseItem

  def create_expense_item(attrs) do
    %ExpenseItem{}
    |> ExpenseItem.changeset(attrs)
    |> Repo.insert()
  end
end
