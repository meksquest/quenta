defmodule Quenta.Expenses.Expense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expenses" do
    field :description, :string
    field :date, :date
    field :amount_cents, :integer
    field :amount_dollars, :decimal, virtual: true
    field :participants_user_ids, {:array, :integer}, virtual: true
    field :paid_by_user_id, :integer, virtual: true

    belongs_to :created_by_user, Quenta.Users.User, foreign_key: :created_by_user_id

    has_many :expense_items, Quenta.ExpenseItems.ExpenseItem, on_replace: :delete

    has_many :expense_participants, Quenta.ExpenseParticipants.ExpenseParticipant,
      on_replace: :delete

    has_many :expense_payments, Quenta.ExpensePayments.ExpensePayment, on_replace: :delete

    belongs_to :currency, Quenta.Currencies.Currency,
      foreign_key: :currency_code,
      references: :code,
      type: :string

    timestamps()
  end

  @fields ~w(description date amount_dollars currency_code created_by_user_id)a
  @virtual_fields ~w(participants_user_ids paid_by_user_id)a

  def changeset(expense, attrs) do
    expense
    |> cast(attrs, @fields ++ @virtual_fields)
    |> cast_assoc(:expense_items,
      sort_param: :expense_items_sort,
      drop_param: :expense_items_drop
    )
    |> put_default_currency()
    |> validate_required(@fields)
    |> validate_number(:amount_dollars, greater_than: 0, less_than_or_equal_to: 21_474_836)
    |> convert_dollars_to_cents()
    |> compute_participants_and_payments()
    |> validate_participants_presence()
    |> validate_participants_total()
    |> validate_payments_total()
    |> assoc_constraint(:created_by_user)
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

  defp compute_participants_and_payments(changeset) do
    amount_cents = amount_cents_from_fields(changeset)
    created_by_user_id = get_field(changeset, :created_by_user_id)
    expense_items = normalize_assoc(get_field(changeset, :expense_items))

    existing_participants = normalize_assoc(get_field(changeset, :expense_participants)) || []
    existing_participant_ids = Enum.map(existing_participants, &assoc_value(&1, :user_id))

    selected_participants =
      get_field(changeset, :participants_user_ids) || existing_participant_ids || []

    existing_payments = normalize_assoc(get_field(changeset, :expense_payments)) || []

    existing_paid_by_user_id =
      case existing_payments do
        [payment | _] -> assoc_value(payment, :user_id)
        _ -> nil
      end

    paid_by_user_id =
      get_field(changeset, :paid_by_user_id) || existing_paid_by_user_id || created_by_user_id

    participant_ids =
      selected_participants
      |> Enum.concat(item_owner_ids(expense_items))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    changeset
    |> put_assoc(
      :expense_participants,
      build_participants(amount_cents, participant_ids, expense_items)
    )
    |> put_assoc(:expense_payments, build_payments(amount_cents, paid_by_user_id))
  end

  defp amount_cents_from_fields(changeset) do
    case get_field(changeset, :amount_cents) do
      nil ->
        case get_field(changeset, :amount_dollars) do
          nil -> nil
          amount -> amount |> normalize_decimal() |> Decimal.mult(100) |> Decimal.to_integer()
        end

      amount_cents ->
        amount_cents
    end
  end

  defp normalize_decimal(%Decimal{} = amount), do: amount
  defp normalize_decimal(amount) when is_integer(amount), do: Decimal.new(amount)
  defp normalize_decimal(amount) when is_float(amount), do: Decimal.from_float(amount)
  defp normalize_decimal(amount) when is_binary(amount), do: Decimal.new(amount)

  defp build_participants(nil, _participant_ids, _expense_items), do: []
  defp build_participants(_amount_cents, [], _expense_items), do: []

  defp build_participants(amount_cents, participant_ids, expense_items) do
    item_totals = item_totals_by_user(expense_items)
    item_total_sum = item_totals |> Map.values() |> Enum.sum()
    remaining = amount_cents - item_total_sum

    per_person =
      if remaining > 0 do
        div(remaining, length(participant_ids))
      else
        0
      end

    remainder =
      if remaining > 0 do
        rem(remaining, length(participant_ids))
      else
        0
      end

    participant_ids
    |> Enum.with_index()
    |> Enum.map(fn {user_id, index} ->
      extra = if index < remainder, do: 1, else: 0
      share_cents = Map.get(item_totals, user_id, 0) + per_person + extra

      %Quenta.ExpenseParticipants.ExpenseParticipant{
        user_id: user_id,
        share_cents: share_cents
      }
    end)
  end

  defp build_payments(nil, _paid_by_user_id), do: []
  defp build_payments(_amount_cents, nil), do: []

  defp build_payments(amount_cents, paid_by_user_id) do
    [
      %Quenta.ExpensePayments.ExpensePayment{
        user_id: paid_by_user_id,
        amount_cents: amount_cents
      }
    ]
  end

  defp item_owner_ids(nil), do: []

  defp item_owner_ids(items) do
    items
    |> Enum.map(&assoc_value(&1, :user_id))
    |> Enum.reject(&is_nil/1)
  end

  defp item_totals_by_user(nil), do: %{}

  defp item_totals_by_user(items) do
    items
    |> Enum.map(fn item -> {assoc_value(item, :user_id), assoc_cents(item, :amount_cents)} end)
    |> Enum.reject(fn {user_id, amount_cents} -> is_nil(user_id) or amount_cents == 0 end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {user_id, amounts} -> {user_id, Enum.sum(amounts)} end)
  end

  defp assoc_value(%Ecto.Changeset{} = changeset, field), do: get_field(changeset, field)
  defp assoc_value(struct, field) when is_map(struct), do: Map.get(struct, field)
  defp assoc_value(_, _field), do: nil

  defp normalize_assoc(%Ecto.Association.NotLoaded{}), do: nil
  defp normalize_assoc(value), do: value

  defp assoc_cents(%Ecto.Changeset{} = changeset, field), do: get_field(changeset, field) || 0
  defp assoc_cents(struct, field) when is_map(struct), do: Map.get(struct, field) || 0
  defp assoc_cents(_, _field), do: 0

  defp validate_participants_presence(changeset) do
    participants = normalize_assoc(get_field(changeset, :expense_participants))
    payments = normalize_assoc(get_field(changeset, :expense_payments))

    case {participants, payments} do
      {nil, nil} ->
        changeset
        |> add_error(:expense_participants, "must be provided")
        |> add_error(:expense_payments, "must be provided")

      {[], _} ->
        add_error(changeset, :expense_participants, "must include at least one participant")

      {_, []} ->
        add_error(changeset, :expense_payments, "must include at least one payment")

      {nil, _} ->
        add_error(changeset, :expense_participants, "must be provided when payments are present")

      {_, nil} ->
        add_error(changeset, :expense_payments, "must be provided when participants are present")

      _ ->
        changeset
    end
  end

  defp validate_participants_total(changeset) do
    participants = normalize_assoc(get_field(changeset, :expense_participants))

    case {get_field(changeset, :amount_cents), participants} do
      {nil, _} ->
        changeset

      {_, nil} ->
        changeset

      {amount_cents, participants} ->
        total_share_cents =
          participants
          |> Enum.map(&assoc_cents(&1, :share_cents))
          |> Enum.sum()

        if total_share_cents == amount_cents do
          changeset
        else
          add_error(changeset, :expense_participants, "must sum to total expense amount")
        end
    end
  end

  defp validate_payments_total(changeset) do
    payments = normalize_assoc(get_field(changeset, :expense_payments))

    case {get_field(changeset, :amount_cents), payments} do
      {nil, _} ->
        changeset

      {_, nil} ->
        changeset

      {amount_cents, payments} ->
        total_payment_cents =
          payments
          |> Enum.map(&assoc_cents(&1, :amount_cents))
          |> Enum.sum()

        if total_payment_cents == amount_cents do
          changeset
        else
          add_error(changeset, :expense_payments, "must sum to total expense amount")
        end
    end
  end
end
