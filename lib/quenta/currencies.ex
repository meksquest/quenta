defmodule Quenta.Currencies do
  @moduledoc """
  Context for working with currencies.
  """

  alias Quenta.Currencies.Currency
  alias Quenta.Repo

  @doc """
  Returns a list of currency options formatted like "USD - United States Dollar".
  """
  def list_currency_options do
    Currency
    |> Repo.all()
    |> Enum.sort_by(& &1.code)
    |> Enum.map(fn currency -> {"#{currency.code} - #{currency.name}", currency.code} end)
  end
end
