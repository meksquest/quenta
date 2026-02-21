defmodule Quenta.Expenses.Expense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expenses" do
    field :description, :string
    field :date, :date
    field :amount_cents, :integer
    field :amount_dollars, :decimal, virtual: true

    belongs_to :user, Quenta.Users.User

    has_many :expense_items, Quenta.ExpenseItems.ExpenseItem, on_replace: :delete

    belongs_to :currency, Quenta.Currencies.Currency,
      foreign_key: :currency_code,
      references: :code,
      type: :string

    timestamps()
  end

  @fields ~w(description date amount_dollars currency_code user_id)a

  def changeset(expense, attrs) do
    expense
    |> cast(attrs, @fields)
    |> cast_assoc(:expense_items,
      sort_param: :expense_items_sort,
      drop_param: :expense_items_drop
    )
    |> put_default_currency()
    |> validate_required(@fields)
    |> validate_number(:amount_dollars, greater_than: 0, less_than_or_equal_to: 21_474_836)
    |> convert_dollars_to_cents()
    |> assoc_constraint(:user)
  end

  defp put_default_currency(changeset) do
    case get_field(changeset, :currency_code) do
      nil -> put_change(changeset, :currency_code, "USD")
      _ -> changeset
    end
  end

  defp convert_dollars_to_cents(changeset) do
    case get_change(changeset, :amount_dollars) do
      nil ->
        changeset

      amount ->
        put_change(changeset, :amount_cents, amount |> Decimal.mult(100) |> Decimal.to_integer())
    end
  end
end
