defmodule Quenta.ExpenseItemsTest do
  use Quenta.DataCase, async: true
  alias Quenta.ExpenseItems

  test "create_expense_item/1 creates a new expense item" do
    user_1 = insert(:user)
    user_2 = insert(:user)
    expense = insert(:expense, created_by_user: user_1)

    params = %{
      "description" => "Giant Mug",
      "amount_dollars" => 15.00,
      "expense_id" => expense.id,
      "user_id" => user_2.id
    }

    assert {:ok, expense_item} = ExpenseItems.create_expense_item(params)
    assert expense_item.description == "Giant Mug"
    assert expense_item.amount_cents == 1500
    assert expense_item.expense_id == expense.id
    assert expense_item.user_id == user_2.id
  end

  test "create_expense_item/1 returns an error when required fields are missing" do
    user_1 = insert(:user)
    user_2 = insert(:user)
    expense = insert(:expense, created_by_user: user_1)

    params = %{
      "description" => "Giant Mug",
      "amount_dollars" => nil,
      "expense_id" => expense.id,
      "user_id" => user_2.id
    }

    assert {:error, changeset} = ExpenseItems.create_expense_item(params)
    assert changeset.valid? == false
    assert changeset.errors[:amount_dollars] != nil
  end
end
