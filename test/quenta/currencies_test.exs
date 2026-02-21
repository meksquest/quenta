defmodule Quenta.CurrenciesTest do
  use Quenta.DataCase, async: true

  alias Quenta.Currencies
  alias Quenta.Currencies.Currency
  alias Quenta.Repo

  describe "list_currency_codes/0" do
    setup do
      Repo.delete_all(Currency)
      :ok
    end

    test "returns sorted currency codes" do
      Repo.insert!(%Currency{code: "USD", name: "United States Dollar"})
      Repo.insert!(%Currency{code: "EUR", name: "Euro"})
      Repo.insert!(%Currency{code: "JPY", name: "Japanese Yen"})

      assert Currencies.list_currency_codes() == ["EUR", "JPY", "USD"]
    end

    test "returns an empty list when no currencies exist" do
      assert Currencies.list_currency_codes() == []
    end
  end
end
