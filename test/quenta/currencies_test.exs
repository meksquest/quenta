defmodule Quenta.CurrenciesTest do
  use Quenta.DataCase, async: false

  alias Quenta.Currencies
  alias Quenta.Currencies.Currency
  alias Quenta.Expenses.Expense
  alias Quenta.Repo

  describe "list_currency_options/0" do
    setup do
      Repo.delete_all(Currency)
      :ok
    end

    test "returns sorted currency options with code and name" do
      create_currency(%{code: "USD", name: "United States Dollar"})
      create_currency(%{code: "EUR", name: "Euro"})
      create_currency(%{code: "JPY", name: "Japanese Yen"})

      assert Currencies.list_currency_options() == [
               {"EUR - Euro", "EUR"},
               {"JPY - Japanese Yen", "JPY"},
               {"USD - United States Dollar", "USD"}
             ]
    end

    test "returns an empty list when no currencies exist" do
      assert Currencies.list_currency_options() == []
    end
  end

  describe "list_currency_options_for_user/1" do
    setup do
      Repo.delete_all(Expense)
      Repo.delete_all(Currency)
      :ok
    end

    test "orders most recently used currencies first for the user" do
      create_currency(%{code: "USD", name: "United States Dollar"})
      create_currency(%{code: "EUR", name: "Euro"})
      create_currency(%{code: "JPY", name: "Japanese Yen"})

      user = insert(:user)
      other_user = insert(:user)

      insert(:expense,
        created_by_user: user,
        currency_code: "EUR",
        inserted_at: ~N[2024-01-01 10:00:00]
      )

      insert(:expense,
        created_by_user: user,
        currency_code: "USD",
        inserted_at: ~N[2024-01-02 12:00:00]
      )

      insert(:expense,
        created_by_user: other_user,
        currency_code: "JPY",
        inserted_at: ~N[2024-01-03 12:00:00]
      )

      assert Currencies.list_currency_options_for_user(user.id) == [
               {"Recently used",
                [
                  {"USD - United States Dollar", "USD"},
                  {"EUR - Euro", "EUR"}
                ]},
               {"All currencies",
                [
                  {"JPY - Japanese Yen", "JPY"}
                ]}
             ]
    end

    test "falls back to sorted list when the user has no expenses" do
      create_currency(%{code: "USD", name: "United States Dollar"})
      create_currency(%{code: "EUR", name: "Euro"})
      create_currency(%{code: "JPY", name: "Japanese Yen"})

      user = insert(:user)

      assert Currencies.list_currency_options_for_user(user.id) == [
               {"EUR - Euro", "EUR"},
               {"JPY - Japanese Yen", "JPY"},
               {"USD - United States Dollar", "USD"}
             ]
    end
  end

  describe "last_used_currency_code_for_user/1" do
    setup do
      Repo.delete_all(Expense)
      Repo.delete_all(Currency)

      create_currency(%{code: "USD", name: "United States Dollar"})
      create_currency(%{code: "EUR", name: "Euro"})
      create_currency(%{code: "JPY", name: "Japanese Yen"})

      :ok
    end

    test "returns nil when the user has no expenses" do
      user = insert(:user)

      assert Currencies.last_used_currency_code_for_user(user.id) == nil
    end

    test "returns the most recently used currency for the user" do
      user = insert(:user)
      other_user = insert(:user)

      insert(:expense,
        created_by_user: user,
        currency_code: "EUR",
        inserted_at: ~N[2024-01-01 10:00:00]
      )

      insert(:expense,
        created_by_user: user,
        currency_code: "USD",
        inserted_at: ~N[2024-01-02 12:00:00]
      )

      insert(:expense,
        created_by_user: other_user,
        currency_code: "JPY",
        inserted_at: ~N[2024-01-03 12:00:00]
      )

      assert Currencies.last_used_currency_code_for_user(user.id) == "USD"
    end
  end

  defp create_currency(attrs) do
    insert(:currency, attrs)
  end
end
