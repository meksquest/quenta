defmodule Quenta.ExpenseCalculatorTest do
  use Quenta.DataCase, async: true
  alias Quenta.ExpenseCalculator

  describe "calculate_balances/3" do
    setup do
      meks = %{id: 1, name: "Meks"}
      george = %{id: 2, name: "George"}
      alice = %{id: 3, name: "Alice"}

      %{
        meks: meks,
        george: george,
        alice: alice,
        users_two: [meks, george],
        users_three: [meks, george, alice]
      }
    end

    test "calculates balances for your supper example", %{users_two: users} do
      # Meks pays $30, has $2 water, George has $5 beer + $3 ice cream
      expense = %{amount_cents: 3000, created_by_user_id: 1}

      expense_items = [
        # Meks water
        %{amount_cents: 200, user_id: 1},
        # George beer
        %{amount_cents: 500, user_id: 2},
        # George ice cream
        %{amount_cents: 300, user_id: 2}
      ]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      assert length(result) == 2

      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))

      # Meks is owed $18
      assert meks_balance.balance == -1800
      # George owes $18
      assert george_balance.balance == 1800
    end

    test "handles case where everyone pays equally", %{users_two: users} do
      expense = %{amount_cents: 2000, created_by_user_id: 1}
      expense_items = []

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))

      # Meks is owed $10
      assert meks_balance.balance == -1000
      # George owes $10
      assert george_balance.balance == 1000
    end

    test "handles case where non-payer has no personal items", %{users_two: users} do
      expense = %{amount_cents: 1000, created_by_user_id: 1}

      expense_items = [
        # Only Meks has personal items
        %{amount_cents: 300, user_id: 1}
      ]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))

      # Shared: $10 - $3 = $7, so $3.50 each
      # Meks: $3 + $3.50 - $10 = -$3.50
      # George: $0 + $3.50 - $0 = $3.50
      assert meks_balance.balance == -350
      assert george_balance.balance == 350
    end

    test "handles three people scenario", %{users_three: users} do
      # Meks pays $30
      expense = %{amount_cents: 3000, created_by_user_id: 1}

      expense_items = [
        # Meks $5
        %{amount_cents: 500, user_id: 1},
        # George $4
        %{amount_cents: 400, user_id: 2},
        # Alice $6
        %{amount_cents: 600, user_id: 3}
      ]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      assert length(result) == 3

      # Shared: $30 - $15 = $15, so $5 each
      # Meks: $5 + $5 - $30 = -$20
      # George: $4 + $5 - $0 = $9
      # Alice: $6 + $5 - $0 = $11

      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))
      alice_balance = Enum.find(result, &(&1.user.id == 3))

      assert meks_balance.balance == -2000
      assert george_balance.balance == 900
      assert alice_balance.balance == 1100
    end

    test "handles case where personal items equal total expense", %{users_two: users} do
      expense = %{amount_cents: 1000, created_by_user_id: 1}

      expense_items = [
        %{amount_cents: 600, user_id: 1},
        %{amount_cents: 400, user_id: 2}
      ]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))

      # No shared amount: $10 - $10 = $0
      # Meks: $6 + $0 - $10 = -$4
      # George: $4 + $0 - $0 = $4
      assert meks_balance.balance == -400
      assert george_balance.balance == 400
    end

    test "handles case where different person pays", %{users_two: users} do
      # George pays
      expense = %{amount_cents: 2000, created_by_user_id: 2}

      expense_items = [
        # Meks $3
        %{amount_cents: 300, user_id: 1},
        # George $5
        %{amount_cents: 500, user_id: 2}
      ]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))

      # Shared: $20 - $8 = $12, so $6 each
      # Meks: $3 + $6 - $0 = $9
      # George: $5 + $6 - $20 = -$9
      assert meks_balance.balance == 900
      assert george_balance.balance == -900
    end

    test "balances always sum to zero", %{users_three: users} do
      expense = %{amount_cents: 5000, created_by_user_id: 2}

      expense_items = [
        %{amount_cents: 1000, user_id: 1},
        %{amount_cents: 800, user_id: 2},
        %{amount_cents: 1200, user_id: 3}
      ]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      total_balance = Enum.sum(Enum.map(result, & &1.balance))
      assert total_balance == 0
    end

    test "handles empty expense items list", %{users_two: users} do
      expense = %{amount_cents: 1000, created_by_user_id: 1}
      expense_items = []

      result = ExpenseCalculator.calculate_balances(expense, expense_items, users)

      assert length(result) == 2

      # Everything is shared equally
      meks_balance = Enum.find(result, &(&1.user.id == 1))
      george_balance = Enum.find(result, &(&1.user.id == 2))

      assert meks_balance.balance == -500
      assert george_balance.balance == 500
    end

    test "handles single user scenario", %{meks: meks} do
      expense = %{amount_cents: 1000, created_by_user_id: 1}
      expense_items = [%{amount_cents: 1000, user_id: 1}]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, [meks])

      assert length(result) == 1
      # Single user always balances to 0
      assert hd(result).balance == 0
    end
  end

  describe "even_split_summary" do
    test "all shared expense (no items)" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      expense =
        insert(:expense,
          amount_cents: 2000,
          date: ~D[2023-10-02],
          created_by_user: user_1
        )

      assert %{
               shared_total_cents: 2000,
               per_person_cents: 1000,
               remainder_cents: 0,
               participants_count: 2
             } = ExpenseCalculator.even_split_summary(expense, [user_1, user_2])
    end

    test "mixed personal items and shared expense" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      expense =
        insert(:expense,
          amount_cents: 2000,
          date: ~D[2023-10-02],
          created_by_user: user_1
        )

      insert(:expense_item, amount_cents: 600, user: user_1, expense: expense)

      assert %{
               shared_total_cents: 1400,
               per_person_cents: 700,
               remainder_cents: 0,
               participants_count: 2
             } = ExpenseCalculator.even_split_summary(expense, [user_1, user_2])
    end

    test "all personal items (no shared expense)" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      expense =
        insert(:expense,
          amount_cents: 2000,
          date: ~D[2023-10-02],
          created_by_user: user_1
        )

      insert(:expense_item, amount_cents: 600, user: user_1, expense: expense)
      insert(:expense_item, amount_cents: 1400, user: user_2, expense: expense)

      assert %{
               shared_total_cents: 0,
               per_person_cents: 0,
               remainder_cents: 0,
               participants_count: 2
             } = ExpenseCalculator.even_split_summary(expense, [user_1, user_2])
    end

    test "remainder handling" do
      user_1 = insert(:user)
      user_2 = insert(:user)

      expense =
        insert(:expense,
          amount_cents: 1001,
          date: ~D[2023-10-02],
          created_by_user: user_1
        )

      assert %{
               shared_total_cents: 1001,
               per_person_cents: 500,
               remainder_cents: 1,
               participants_count: 2
             } = ExpenseCalculator.even_split_summary(expense, [user_1, user_2])
    end

    test "single participant" do
      user_1 = insert(:user)

      expense =
        insert(:expense,
          amount_cents: 1000,
          date: ~D[2023-10-02],
          created_by_user: user_1
        )

      assert %{
               shared_total_cents: 1000,
               per_person_cents: 1000,
               remainder_cents: 0,
               participants_count: 1
             } = ExpenseCalculator.even_split_summary(expense, [user_1])
    end

    test "zero participants" do
      user_1 = insert(:user)

      expense =
        insert(:expense,
          amount_cents: 1000,
          date: ~D[2023-10-02],
          created_by_user: user_1
        )

      assert %{
               shared_total_cents: 0,
               per_person_cents: 0,
               remainder_cents: 0,
               participants_count: 0
             } = ExpenseCalculator.even_split_summary(expense, [])
    end
  end
end
