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
      Repo.insert!(%Currency{code: "USD", name: "United States Dollar"})
      Repo.insert!(%Currency{code: "EUR", name: "Euro"})
      Repo.insert!(%Currency{code: "JPY", name: "Japanese Yen"})

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
      Repo.insert!(%Currency{code: "USD", name: "United States Dollar"})
      Repo.insert!(%Currency{code: "EUR", name: "Euro"})
      Repo.insert!(%Currency{code: "JPY", name: "Japanese Yen"})

      user = insert(:user)
      other_user = insert(:user)

      Repo.insert!(%Expense{
        description: "Older EUR",
        amount_cents: 100,
        date: ~D[2024-01-01],
        user_id: user.id,
        currency_code: "EUR",
        inserted_at: ~N[2024-01-01 10:00:00],
        updated_at: ~N[2024-01-01 10:00:00]
      })

      Repo.insert!(%Expense{
        description: "Recent USD",
        amount_cents: 200,
        date: ~D[2024-01-02],
        user_id: user.id,
        currency_code: "USD",
        inserted_at: ~N[2024-01-02 12:00:00],
        updated_at: ~N[2024-01-02 12:00:00]
      })

      Repo.insert!(%Expense{
        description: "Other user JPY",
        amount_cents: 300,
        date: ~D[2024-01-03],
        user_id: other_user.id,
        currency_code: "JPY",
        inserted_at: ~N[2024-01-03 12:00:00],
        updated_at: ~N[2024-01-03 12:00:00]
      })

      assert Currencies.list_currency_options_for_user(user.id) == [
               {"USD - United States Dollar", "USD"},
               {"EUR - Euro", "EUR"},
               {"JPY - Japanese Yen", "JPY"}
             ]
    end

    test "falls back to sorted list when the user has no expenses" do
      Repo.insert!(%Currency{code: "USD", name: "United States Dollar"})
      Repo.insert!(%Currency{code: "EUR", name: "Euro"})
      Repo.insert!(%Currency{code: "JPY", name: "Japanese Yen"})

      user = insert(:user)

      assert Currencies.list_currency_options_for_user(user.id) == [
               {"EUR - Euro", "EUR"},
               {"JPY - Japanese Yen", "JPY"},
               {"USD - United States Dollar", "USD"}
             ]
    end
  end
end
