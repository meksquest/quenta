defmodule Quenta.Currencies do
  @moduledoc """
  Context for working with currencies.
  """

  alias Quenta.Currencies.Currency
  alias Quenta.Expenses.Expense
  alias Quenta.Repo

  import Ecto.Query, only: [from: 2]

  @doc """
  Returns a list of currency options formatted like "USD - United States Dollar".
  """
  def list_currency_options do
    Currency
    |> Repo.all()
    |> Enum.sort_by(& &1.code)
    |> Enum.map(fn currency -> {"#{currency.code} - #{currency.name}", currency.code} end)
  end

  @doc """
  Returns currency options with the most recently used currencies for the user at the top.
  """
  def list_currency_options_for_user(user_id) do
    recent_currency_codes =
      from(e in Expense,
        where: e.created_by_user_id == ^user_id,
        group_by: e.currency_code,
        order_by: [desc: max(e.inserted_at)],
        select: e.currency_code
      )
      |> Repo.all()

    currencies = Repo.all(Currency)

    {recent_currencies, remaining_currencies} =
      currencies
      |> Enum.split_with(fn currency -> currency.code in recent_currency_codes end)

    recent_sorted =
      recent_currency_codes
      |> Enum.map(fn code -> Enum.find(recent_currencies, &(&1.code == code)) end)
      |> Enum.reject(&is_nil/1)

    remaining_sorted =
      remaining_currencies
      |> Enum.sort_by(& &1.code)

    recent_options =
      Enum.map(recent_sorted, fn currency ->
        {"#{currency.code} - #{currency.name}", currency.code}
      end)

    remaining_options =
      Enum.map(remaining_sorted, fn currency ->
        {"#{currency.code} - #{currency.name}", currency.code}
      end)

    case recent_options do
      [] ->
        remaining_options

      _ ->
        [
          {"Recently used", recent_options},
          {"All currencies", remaining_options}
        ]
    end
  end

  @doc """
  Returns the most recently used currency code for the user, or nil if none.
  """
  def last_used_currency_code_for_user(user_id) do
    from(e in Expense,
      where: e.created_by_user_id == ^user_id,
      order_by: [desc: e.inserted_at],
      select: e.currency_code,
      limit: 1
    )
    |> Repo.one()
  end
end
