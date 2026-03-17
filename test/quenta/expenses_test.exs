defmodule Quenta.ExpensesTest do
  use Quenta.DataCase, async: true
  import Ecto.Query
  alias Quenta.Expenses

  describe "change_expense/2" do
    test "returns a changeset for an existing expense" do
      user = insert(:user)
      other_user = insert(:user)

      expense =
        insert(:expense,
          description: "Test Expense",
          amount_cents: 1000,
          date: ~D[2023-10-01],
          created_by_user: user
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 500)
      insert(:expense_participant, expense: expense, user: other_user, share_cents: 500)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      expense = Expenses.get_expense_for_edit!(expense.id)

      changeset = Expenses.change_expense(expense, %{"description" => "Updated Expense"})
      assert changeset.valid?
      assert changeset.changes.description == "Updated Expense"
    end

    test "returns an invalid changeset when missing required fields" do
      user = insert(:user)
      other_user = insert(:user)

      expense =
        insert(:expense,
          description: "Test Expense",
          amount_cents: 1000,
          date: ~D[2023-10-01],
          created_by_user: user
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 500)
      insert(:expense_participant, expense: expense, user: other_user, share_cents: 500)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      expense = Expenses.get_expense_for_edit!(expense.id)

      changeset = Expenses.change_expense(expense, %{"description" => nil})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :description)
    end
  end

  describe "list_user_settlements_by_currency/3" do
    test "returns only settlements involving the user" do
      meks = insert(:user, name: "Meks")
      sam = insert(:user, name: "Sam")
      george = insert(:user, name: "George")

      expense =
        insert(:expense,
          amount_cents: 1000,
          currency_code: "AUD",
          created_by_user: meks
        )

      insert(:expense_item, expense: expense, user: sam, amount_cents: 600)
      insert(:expense_item, expense: expense, user: meks, amount_cents: 400)

      expense = Quenta.Repo.preload(expense, [:expense_items, :created_by_user])

      assert Expenses.list_user_settlements_by_currency([expense], [meks, sam, george], george.id) ==
               []

      assert [{"AUD", [sam_settlement]}] =
               Expenses.list_user_settlements_by_currency([expense], [meks, sam, george], sam.id)

      assert sam_settlement.direction == :you_owe
      assert sam_settlement.other_user.id == meks.id
      assert sam_settlement.amount_cents == 600

      assert [{"AUD", [meks_settlement]}] =
               Expenses.list_user_settlements_by_currency([expense], [meks, sam, george], meks.id)

      assert meks_settlement.direction == :owed_to_you
      assert meks_settlement.other_user.id == sam.id
      assert meks_settlement.amount_cents == 600
    end

    test "uses expense participants when calculating settlements" do
      meks = insert(:user, name: "Meks")
      george = insert(:user, name: "George")
      sam = insert(:user, name: "Sam")

      expense =
        insert(:expense,
          amount_cents: 2000,
          currency_code: "USD",
          created_by_user: george
        )

      insert(:expense_participant, expense: expense, user: meks, share_cents: 1000)
      insert(:expense_participant, expense: expense, user: george, share_cents: 1000)

      expense = Quenta.Repo.preload(expense, [:expense_items, :expense_participants])

      assert [{"USD", [settlement]}] =
               Expenses.list_user_settlements_by_currency(
                 [expense],
                 [meks, george, sam],
                 meks.id
               )

      assert settlement.direction == :you_owe
      assert settlement.other_user.id == george.id
      assert settlement.amount_cents == 1000
    end
  end

  describe "participants_for_expense/2" do
    test "returns only expense participants when present" do
      meks = insert(:user, name: "Meks")
      george = insert(:user, name: "George")
      sam = insert(:user, name: "Sam")

      expense =
        insert(:expense,
          amount_cents: 2000,
          currency_code: "USD",
          created_by_user: george
        )

      insert(:expense_participant, expense: expense, user: meks, share_cents: 1000)
      insert(:expense_participant, expense: expense, user: george, share_cents: 1000)

      expense = Quenta.Repo.preload(expense, [:expense_participants])

      participants = Expenses.participants_for_expense(expense, [meks, george, sam])

      participant_ids = participants |> Enum.map(& &1.id) |> Enum.sort()
      assert participant_ids == Enum.sort([meks.id, george.id])
    end
  end

  describe "balances_for_expense/2" do
    test "calculates balances using only expense participants" do
      meks = insert(:user, name: "Meks")
      george = insert(:user, name: "George")
      sam = insert(:user, name: "Sam")

      expense =
        insert(:expense,
          amount_cents: 2000,
          currency_code: "USD",
          created_by_user: george
        )

      insert(:expense_participant, expense: expense, user: meks, share_cents: 1000)
      insert(:expense_participant, expense: expense, user: george, share_cents: 1000)

      expense = Quenta.Repo.preload(expense, [:expense_items, :expense_participants])

      balances = Expenses.balances_for_expense(expense, [meks, george, sam])

      assert length(balances) == 2
      meks_balance = Enum.find(balances, &(&1.user.id == meks.id))
      george_balance = Enum.find(balances, &(&1.user.id == george.id))

      assert meks_balance.balance == 1000
      assert george_balance.balance == -1000
    end
  end

  describe "create_expense/1" do
    test "creates a new expense" do
      user = insert(:user)
      other_user = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id, other_user.id],
        "paid_by_user_id" => user.id
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      assert expense.description == "Lunch"
      assert expense.amount_cents == 1500
      assert expense.date == ~D[2023-10-01]
      assert expense.created_by_user_id == user.id
    end

    test "defaults currency_code to USD when missing" do
      user = insert(:user)
      other_user = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id, other_user.id],
        "paid_by_user_id" => user.id
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      expense = Quenta.Repo.get!(Quenta.Expenses.Expense, expense.id)
      assert expense.currency_code == "USD"
    end

    test "creates a new expense and associated expense_item" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user_1.id,
        "participants_user_ids" => [user_1.id, user_2.id],
        "paid_by_user_id" => user_1.id,
        "expense_items" => [
          %{
            description: "Item 1",
            amount_dollars: 5.00,
            user_id: user_2.id
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
      assert expense_item.user_id == user_2.id
    end

    test "creates a new expense with participants and payments" do
      user = insert(:user)
      other_user = insert(:user)

      params = %{
        "description" => "Dinner",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id, other_user.id],
        "paid_by_user_id" => user.id
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      expense = Quenta.Repo.preload(expense, [:expense_participants, :expense_payments])

      assert length(expense.expense_participants) == 2
      assert length(expense.expense_payments) == 1
      assert Enum.sum(Enum.map(expense.expense_participants, & &1.share_cents)) == 1000
      assert Enum.sum(Enum.map(expense.expense_payments, & &1.amount_cents)) == 1000
    end

    test "returns an error when participants are missing but payments are provided" do
      user = insert(:user)

      params = %{
        "description" => "Dinner",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [],
        "paid_by_user_id" => user.id
      }

      assert {:error, changeset} = Expenses.create_expense(params)
      assert changeset.valid? == false
      assert changeset.errors[:expense_participants] != nil
    end

    test "defaults payer to creator when not provided" do
      user = insert(:user)
      other_user = insert(:user)

      params = %{
        "description" => "Dinner",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id, other_user.id]
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      expense = Quenta.Repo.preload(expense, :expense_payments)
      user_id = user.id
      assert [%{user_id: ^user_id}] = expense.expense_payments
      assert Enum.sum(Enum.map(expense.expense_payments, & &1.amount_cents)) == 1000
    end

    test "returns an error when required fields are missing" do
      user = insert(:user)

      params = %{
        "description" => "Dinner",
        # Missing amount_cents
        "amount_cents" => nil,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id
      }

      assert {:error, changeset} = Expenses.create_expense(params)
      assert changeset.valid? == false
      assert changeset.errors[:amount_dollars] != nil
    end

    test "returns an error when participant shares do not match total" do
      user = insert(:user)
      other_user = insert(:user)

      params = %{
        "description" => "Dinner",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id, other_user.id],
        "paid_by_user_id" => user.id,
        "expense_items" => [
          %{"description" => "Overage", "amount_dollars" => 7.00, "user_id" => user.id},
          %{"description" => "Overage 2", "amount_dollars" => 4.00, "user_id" => other_user.id}
        ]
      }

      assert {:error, changeset} = Expenses.create_expense(params)
      assert changeset.valid? == false
      assert changeset.errors[:expense_participants] != nil
    end

    test "creates a payment that matches the total amount" do
      user = insert(:user)
      other_user = insert(:user)

      params = %{
        "description" => "Dinner",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id, other_user.id],
        "paid_by_user_id" => user.id
      }

      assert {:ok, expense} = Expenses.create_expense(params)
      expense = Quenta.Repo.preload(expense, :expense_payments)
      assert Enum.sum(Enum.map(expense.expense_payments, & &1.amount_cents)) == 1000
    end

    test "broadcasts expense_added upon success" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      params = %{
        "description" => "Lunch",
        "amount_dollars" => 15.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user_1.id,
        "participants_user_ids" => [user_1.id, user_2.id],
        "paid_by_user_id" => user_1.id,
        "expense_items" => [
          %{
            description: "Item 1",
            amount_dollars: 5.00,
            user_id: user_2.id
          }
        ]
      }

      Quenta.PubSub.subscribe_to_expense_added()
      assert {:ok, %{id: created_expense_id}} = Expenses.create_expense(params)
      assert_receive {:expense_added, %{id: ^created_expense_id}}
    end

    test "does not broadcas expense_added upon failure" do
      user = insert(:user)

      params = %{
        "description" => "Dinner",
        # Missing amount_cents
        "amount_cents" => nil,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id
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
      insert(:expense,
        description: "Coffee",
        amount_cents: 500,
        date: ~D[2023-10-02],
        created_by_user: user
      )

    assert [retrieved_expense] = Expenses.list_expenses()
    assert retrieved_expense.description == "Coffee"
    assert retrieved_expense.amount_cents == 500
    assert retrieved_expense.date == ~D[2023-10-02]
    assert retrieved_expense.id == expense.id
  end

  test "list_expenses/0 orders by date desc with stable tie-breakers" do
    user = insert(:user)

    expense_older = insert(:expense, date: ~D[2023-09-30], created_by_user: user)
    expense_newer = insert(:expense, date: ~D[2023-10-02], created_by_user: user)
    expense_same_date_early = insert(:expense, date: ~D[2023-10-01], created_by_user: user)
    expense_same_date_late = insert(:expense, date: ~D[2023-10-01], created_by_user: user)

    expense_same_date_same_time_low_id =
      insert(:expense, date: ~D[2023-10-01], created_by_user: user)

    expense_same_date_same_time_high_id =
      insert(:expense, date: ~D[2023-10-01], created_by_user: user)

    base_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    early = NaiveDateTime.add(base_time, -60, :second)
    same_time = NaiveDateTime.add(base_time, -30, :second)
    late = NaiveDateTime.add(base_time, -10, :second)

    Quenta.Repo.update_all(
      from(e in Quenta.Expenses.Expense, where: e.id == ^expense_same_date_early.id),
      set: [inserted_at: early]
    )

    Quenta.Repo.update_all(
      from(e in Quenta.Expenses.Expense, where: e.id == ^expense_same_date_late.id),
      set: [inserted_at: late]
    )

    Quenta.Repo.update_all(
      from(e in Quenta.Expenses.Expense, where: e.id == ^expense_same_date_same_time_low_id.id),
      set: [inserted_at: same_time]
    )

    Quenta.Repo.update_all(
      from(e in Quenta.Expenses.Expense, where: e.id == ^expense_same_date_same_time_high_id.id),
      set: [inserted_at: same_time]
    )

    ids = Expenses.list_expenses() |> Enum.map(& &1.id)

    assert ids == [
             expense_newer.id,
             expense_same_date_late.id,
             expense_same_date_same_time_high_id.id,
             expense_same_date_same_time_low_id.id,
             expense_same_date_early.id,
             expense_older.id
           ]
  end

  describe "get_expense!/2" do
    test "returns the expense by id" do
      user = insert(:user)

      expense =
        insert(:expense,
          description: "Taxi",
          amount_cents: 2200,
          date: ~D[2023-10-03],
          created_by_user: user
        )

      retrieved = Expenses.get_expense!(expense.id)

      assert retrieved.id == expense.id
      assert retrieved.description == "Taxi"
      assert retrieved.amount_cents == 2200
      assert retrieved.date == ~D[2023-10-03]
      assert retrieved.created_by_user_id == user.id
    end

    test "raises when the expense is not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Expenses.get_expense!(999_999)
      end
    end
  end

  describe "get_expense_for_edit!/1" do
    test "hydrates amount_dollars for expense and items" do
      user = insert(:user)
      expense = insert(:expense, created_by_user: user, amount_cents: 1234)
      _item = insert(:expense_item, expense: expense, user: user, amount_cents: 567)

      expense = Expenses.get_expense_for_edit!(expense.id)

      assert Decimal.equal?(expense.amount_dollars, Decimal.new("12.34"))
      assert Decimal.to_string(expense.amount_dollars, :normal) == "12.34"
      assert [loaded_item] = expense.expense_items
      assert Decimal.equal?(loaded_item.amount_dollars, Decimal.new("5.67"))
      assert Decimal.to_string(loaded_item.amount_dollars, :normal) == "5.67"
    end

    test "preserves trailing zeros for whole-dollar amounts" do
      user = insert(:user)
      expense = insert(:expense, created_by_user: user, amount_cents: 2500)
      _item = insert(:expense_item, expense: expense, user: user, amount_cents: 3000)

      expense = Expenses.get_expense_for_edit!(expense.id)

      assert Decimal.to_string(expense.amount_dollars, :normal) == "25.00"
      assert [loaded_item] = expense.expense_items
      assert Decimal.to_string(loaded_item.amount_dollars, :normal) == "30.00"
    end
  end

  describe "update_expense/2" do
    test "defaults currency_code to USD on update when set to nil" do
      user = insert(:user)

      expense =
        insert(:expense,
          created_by_user: user,
          description: "Old",
          amount_cents: 1000,
          date: ~D[2023-10-01],
          currency_code: "NZD"
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 1000)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      params = %{
        "description" => "Old",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-01],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id],
        "paid_by_user_id" => user.id,
        "currency_code" => nil
      }

      assert {:ok, updated} = Expenses.update_expense(expense, params)
      updated = Quenta.Repo.get!(Quenta.Expenses.Expense, updated.id)
      assert updated.currency_code == "USD"
    end

    test "updates an expense and its items" do
      user = insert(:user)

      expense =
        insert(:expense,
          created_by_user: user,
          description: "Old",
          amount_cents: 1000,
          date: ~D[2023-10-01]
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 1000)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      item =
        insert(:expense_item,
          expense: expense,
          user: user,
          description: "Old item",
          amount_cents: 250
        )

      params = %{
        "description" => "New",
        "amount_dollars" => 20.00,
        "date" => ~D[2023-10-02],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id],
        "paid_by_user_id" => user.id,
        "expense_items" => [
          %{
            "id" => item.id,
            "description" => "Updated item",
            "amount_dollars" => 7.50,
            "user_id" => user.id
          },
          %{
            "description" => "New item",
            "amount_dollars" => 2.25,
            "user_id" => user.id
          }
        ]
      }

      assert {:ok, updated} = Expenses.update_expense(expense, params)
      assert updated.description == "New"
      assert updated.amount_cents == 2000
      assert updated.date == ~D[2023-10-02]

      updated = Quenta.Repo.preload(updated, :expense_items)
      assert length(updated.expense_items) == 2

      assert Enum.any?(
               updated.expense_items,
               &(&1.description == "Updated item" && &1.amount_cents == 750)
             )

      assert Enum.any?(
               updated.expense_items,
               &(&1.description == "New item" && &1.amount_cents == 225)
             )
    end

    test "drops an expense item when marked for removal" do
      user = insert(:user)

      expense =
        insert(:expense,
          created_by_user: user,
          description: "Old",
          amount_cents: 1000,
          date: ~D[2023-10-01]
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 1000)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      item_1 =
        insert(:expense_item,
          expense: expense,
          user: user,
          description: "Keep item",
          amount_cents: 300
        )

      item_2 =
        insert(:expense_item,
          expense: expense,
          user: user,
          description: "Drop item",
          amount_cents: 200
        )

      params = %{
        "description" => "Updated",
        "amount_dollars" => 10.00,
        "date" => ~D[2023-10-02],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id],
        "paid_by_user_id" => user.id,
        "expense_items_sort" => ["0", "1"],
        "expense_items_drop" => ["1"],
        "expense_items" => %{
          "0" => %{
            "id" => item_1.id,
            "description" => "Keep item",
            "amount_dollars" => 3.00,
            "user_id" => user.id
          },
          "1" => %{
            "id" => item_2.id,
            "description" => "Drop item",
            "amount_dollars" => 2.00,
            "user_id" => user.id
          }
        }
      }

      assert {:ok, updated} = Expenses.update_expense(expense, params)

      updated = Quenta.Repo.preload(updated, :expense_items)
      assert length(updated.expense_items) == 1
      assert Enum.any?(updated.expense_items, &(&1.id == item_1.id))
      refute Enum.any?(updated.expense_items, &(&1.id == item_2.id))
    end

    test "broadcasts expense_updated upon success" do
      user = insert(:user)

      expense =
        insert(:expense,
          created_by_user: user,
          description: "Old",
          amount_cents: 1000,
          date: ~D[2023-10-01]
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 1000)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      params = %{
        "description" => "New",
        "amount_dollars" => 12.50,
        "date" => ~D[2023-10-02],
        "created_by_user_id" => user.id,
        "participants_user_ids" => [user.id],
        "paid_by_user_id" => user.id
      }

      Quenta.PubSub.subscribe_to_expense_updated()
      assert {:ok, %{id: updated_expense_id}} = Expenses.update_expense(expense, params)
      assert_receive {:expense_updated, %{id: ^updated_expense_id}}
    end

    test "does not broadcast expense_updated upon failure" do
      user = insert(:user)

      expense =
        insert(:expense,
          created_by_user: user,
          description: "Old",
          amount_cents: 1000,
          date: ~D[2023-10-01]
        )

      insert(:expense_participant, expense: expense, user: user, share_cents: 1000)
      insert(:expense_payment, expense: expense, user: user, amount_cents: 1000)

      params = %{
        "description" => "",
        "amount_dollars" => nil,
        "date" => nil,
        "created_by_user_id" => nil
      }

      Quenta.PubSub.subscribe_to_expense_updated()
      assert {:error, _changeset} = Expenses.update_expense(expense, params)
      refute_received {:expense_updated, _}
    end
  end

  describe "delete_expense/1" do
    test "deletes the expense and its expense items" do
      user = insert(:user)
      expense = insert(:expense, created_by_user: user)

      expense_item =
        insert(:expense_item,
          expense: expense,
          user: user
        )

      assert {:ok, _} = Expenses.delete_expense(expense)
      assert_raise Ecto.NoResultsError, fn -> Expenses.get_expense!(expense.id) end
      assert Quenta.Repo.get(Quenta.ExpenseItems.ExpenseItem, expense_item.id) == nil
    end

    test "broadcasts expense_deleted upon success" do
      user = insert(:user)
      expense = insert(:expense, created_by_user: user)

      Quenta.PubSub.subscribe_to_expense_deleted()
      assert {:ok, %{id: deleted_expense_id}} = Expenses.delete_expense(expense)
      assert_received {:expense_deleted, %{id: received_expense_id}}
      assert deleted_expense_id == received_expense_id
    end
  end
end
