defmodule QuentaWeb.ExpensesLive.FormComponent do
  use QuentaWeb, :live_component

  alias Quenta.Currencies
  alias Quenta.Expenses
  alias Quenta.Expenses.Expense
  alias Quenta.Users

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def update(%{user_id: user_id} = _assigns, socket) do
    last_used_currency_code = Currencies.last_used_currency_code_for_user(user_id)

    form =
      %Expense{}
      |> Expenses.change_expense(%{currency_code: last_used_currency_code, expense_items: []})
      |> to_form()

    user_options = Users.list_users() |> Enum.map(fn user -> {user.name, user.id} end)

    currency_options = Currencies.list_currency_options_for_user(user_id)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:user_options, user_options)
      |> assign(:currency_options, currency_options)
      |> assign(:user_id, user_id)

    {:ok, socket}
  end

  def handle_event("validate", %{"expense" => expense_attrs}, socket) do
    form = %Expense{} |> Expenses.change_expense(expense_attrs) |> to_form(action: :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"expense" => expense_attrs}, socket) do
    case Expenses.create_expense(expense_attrs) do
      {:ok, _} ->
        %{user_id: user_id} = socket.assigns

        {:noreply,
         socket
         |> put_flash(:info, "Expense created successfully!")
         |> redirect(to: ~p"/users/#{user_id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
