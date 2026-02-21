defmodule Quenta.Currencies do
  @moduledoc """
  Context for working with currencies.
  """

  alias Quenta.Currencies.Currency
  alias Quenta.Repo

  @doc """
  Returns a list of currency codes sorted alphabetically.
  """
  def list_currency_codes do
    Currency
    |> Repo.all()
    |> Enum.map(& &1.code)
    |> Enum.sort()
  end
end
