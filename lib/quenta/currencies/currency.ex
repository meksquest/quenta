defmodule Quenta.Currencies.Currency do
  @moduledoc """
  Schema representing a currency.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "currencies" do
    field :code, :string, primary_key: true
    field :name, :string

    timestamps()
  end

  @fields ~w(code name)a

  @doc """
  Builds a changeset for creating or updating currencies.
  """
  def changeset(currency, attrs) do
    currency
    |> cast(attrs, @fields)
    |> validate_required([:code, :name])
    |> validate_length(:code, is: 3)
    |> update_change(:code, &String.upcase/1)
  end
end
