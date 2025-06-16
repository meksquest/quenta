defmodule Quenta.ExpensesTest do
  use Quenta.DataCase, async: true
  alias Quenta.Expenses

  test "change_expense/2 returns a changeset for an existing expense" do
    expense = %Quenta.Expenses.Expense{
      id: 1,
      description: "Test Expense",
      amount_dollars: 10.00,
      date: ~D[2023-10-01],
      user_id: 1
    }

    changeset = Expenses.change_expense(expense, %{"description" => "Updated Expense"})
    assert changeset.valid?
    assert changeset.changes.description == "Updated Expense"
  end

  test "change_expense/2 return an invalid changeset when missing required fields" do
    expense = %Quenta.Expenses.Expense{
      id: 1,
      description: "Test Expense",
      amount_dollars: 10.00,
      date: ~D[2023-10-01],
      user_id: 1
    }

    changeset = Expenses.change_expense(expense, %{"description" => nil})
    refute changeset.valid?
    assert [description: {"can't be blank", _}] = changeset.errors
  end

  test "create_expense/1 creates a new expense" do
    params = %{
      "description" => "Lunch",
      "amount_dollars" => 15.00,
      "date" => ~D[2023-10-01],
      "user_id" => 1
    }

    assert {:ok, expense} = Expenses.create_expense(params)
    assert expense.description == "Lunch"
    assert expense.amount_cents == 1500
    assert expense.date == ~D[2023-10-01]
  end

  test "create_expense/1 creates a new expense and associated expense_item" do
    params = %{
      "description" => "Lunch",
      "amount_dollars" => 15.00,
      "date" => ~D[2023-10-01],
      "user_id" => 1,
      "expense_items" => [
        %{
          description: "Item 1",
          amount_dollars: 5.00,
          user_id: 2
        }
      ]
    }

    assert {:ok, expense} = Expenses.create_expense(params)
    Quenta.Repo.preload(expense, :expense_items)
    assert expense.description == "Lunch"
    assert expense.amount_cents == 1500
    assert expense.date == ~D[2023-10-01]
    assert [expense_item] = expense.expense_items
    assert expense_item.description == "Item 1"
    assert expense_item.amount_cents == 500
    assert expense_item.user_id == 2
  end

  test "create_expense/1 returns an error when required fields are missing" do
    params = %{
      "description" => "Dinner",
      # Missing amount_cents
      "amount_cents" => nil,
      "date" => ~D[2023-10-01],
      "user_id" => 1
    }

    assert {:error, changeset} = Expenses.create_expense(params)
    assert changeset.valid? == false
    assert changeset.errors[:amount_dollars] != nil
  end

  test "list_expenses/0 returns an empty list when no expenses exist" do
    assert [] = Expenses.list_expenses()
  end

  test "list_expenses/0 returns all expenses" do
    # Create an expense to test listing
    params = %{
      "description" => "Coffee",
      "amount_dollars" => 5,
      "date" => ~D[2023-10-02],
      "user_id" => 1
    }

    {:ok, _expense} = Expenses.create_expense(params)

    assert [expense] = Expenses.list_expenses()
    assert expense.description == "Coffee"
    assert expense.amount_cents == 500
    assert expense.date == ~D[2023-10-02]
  end
end
