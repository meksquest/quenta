defmodule Quenta.Currency do
  @moduledoc """
  Module to handle currency transformations.
  """

  @doc """
  Formats a number into a human-readable string with comma separators for thousands.

  ## Examples

      iex> Quenta.Currency.format_cents_to_dollars(0)
      "$0.00"

      iex> Quenta.Currency.format_cents_to_dollars(-2300)
      "$-23.00"

      iex> Quenta.Currency.format_cents_to_dollars(23)
      "$0.23"

      iex> Quenta.Currency.format_cents_to_dollars(8_675_309)
      "$86,753.09"

      iex> Quenta.Currency.format_cents_to_dollars(0.6)
      "$0.01"

      iex> Quenta.Currency.format_cents_to_dollars(0.3)
      "$0.00"
  """
  def format_cents_to_dollars(amount_cents) do
    dollars = amount_cents / 100

    is_negative = dollars < 0

    abs_number_string =
      :erlang.float_to_binary(abs(dollars), decimals: 2)
      |> to_string()

    {integer_part_string, fractional_part_string} =
      case String.split(abs_number_string, ".", parts: 2) do
        [int_part] -> {int_part, ""}
        [int_part, frac_part] -> {int_part, "." <> frac_part}
      end

    formatted_integer_part =
      integer_part_string
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    prefix = if is_negative, do: "-", else: ""
    formatted_dollars = prefix <> formatted_integer_part <> fractional_part_string
    "$#{formatted_dollars}"
  end
end
