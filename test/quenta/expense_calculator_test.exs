defmodule Quenta.ExpenseCalculatorTest do
  use ExUnit.Case
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
      expense = %{amount_cents: 3000, user_id: 1}

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
      expense = %{amount_cents: 2000, user_id: 1}
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
      expense = %{amount_cents: 1000, user_id: 1}

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
      expense = %{amount_cents: 3000, user_id: 1}

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
      expense = %{amount_cents: 1000, user_id: 1}

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
      expense = %{amount_cents: 2000, user_id: 2}

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
      expense = %{amount_cents: 5000, user_id: 2}

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
      expense = %{amount_cents: 1000, user_id: 1}
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
      expense = %{amount_cents: 1000, user_id: 1}
      expense_items = [%{amount_cents: 1000, user_id: 1}]

      result = ExpenseCalculator.calculate_balances(expense, expense_items, [meks])

      assert length(result) == 1
      # Single user always balances to 0
      assert hd(result).balance == 0
    end
  end
end
