defmodule Quenta.ExpensesTest do
  use Quenta.DataCase, async: true
  alias Quenta.Expenses

  describe "change_expense/2" do
    test "returns a changeset for an existing expense" do
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

    test "returns an invalid changeset when missing required fields" do
      expense = %Quenta.Expenses.Expense{
        id: 1,
        description: "Test Expense",
        amount_dollars: 10.00,
        date: ~D[2023-10-01],
        user_id: 1
      }

      changeset = Expenses.change_expense(expense, %{"description" => nil})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :description)
    end
  end

  describe "create_expense/1" do
    test "creates a new expense" do
      user = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "user_id" => user.id
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      assert expense.description == "Lunch"
      assert expense.amount_cents == 1500
      assert expense.date == ~D[2023-10-01]
      assert expense.user_id == user.id
    end

    test "creates a new expense and associated expense_item" do
      user1 = insert(:user)
      user2 = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "user_id" => user1.id,
        "expense_items" => [
          %{
            description: "Item 1",
            amount_dollars: 5.00,
            user_id: user2.id
          }
        ]
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      expense = Quenta.Repo.preload(expense, :expense_items)
      assert expense.description == "Lunch"
      assert expense.amount_cents == 1500
      assert expense.date == ~D[2023-10-01]
      assert [expense_item] = expense.expense_items
      assert expense_item.description == "Item 1"
      assert expense_item.amount_cents == 500
      assert expense_item.user_id == user2.id
    end

    test "returns an error when required fields are missing" do
      user = insert(:user)

      params = %{
        "description" => "Dinner",
        # Missing amount_cents
        "amount_cents" => nil,
        "date" => ~D[2023-10-01],
        "user_id" => user.id
      }

      assert {:error, changeset} = Expenses.create_expense(params)
      assert changeset.valid? == false
      assert changeset.errors[:amount_dollars] != nil
    end

    test "broadcasts expense_added upon success" do
      user1 = insert(:user)
      user2 = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "user_id" => user1.id,
        "expense_items" => [
          %{
            description: "Item 1",
            amount_dollars: 5.00,
            user_id: user2.id
          }
        ]
      }

      Quenta.PubSub.subscribe_to_expense_added()
      assert {:ok, %{id: created_expense_id}} = Expenses.create_expense(params)
      assert_received {:expense_added, %{id: received_expense_id}}
      assert created_expense_id == received_expense_id
    end

    test "does not broadcas expense_added upon failure" do
      user = insert(:user)

      params = %{
        "description" => "Dinner",
        # Missing amount_cents
        "amount_cents" => nil,
        "date" => ~D[2023-10-01],
        "user_id" => user.id
      }

      Quenta.PubSub.subscribe_to_expense_added()
      assert {:error, _changeset} = Expenses.create_expense(params)
      refute_received {:expense_added, _}
    end
  end

  test "list_expenses/0 returns an empty list when no expenses exist" do
    assert [] = Expenses.list_expenses()
  end

  test "list_expenses/0 returns all expenses" do
    user = insert(:user)

    expense =
      insert(:expense, description: "Coffee", amount_cents: 500, date: ~D[2023-10-02], user: user)

    assert [retrieved_expense] = Expenses.list_expenses()
    assert retrieved_expense.description == "Coffee"
    assert retrieved_expense.amount_cents == 500
    assert retrieved_expense.date == ~D[2023-10-02]
    assert retrieved_expense.id == expense.id
  end
end
