defmodule QuentaWeb.ExpensesLive.Edit do
  use QuentaWeb, :live_view

  alias Quenta.Expenses
  alias Quenta.Users
  alias Quenta.Currencies

  def mount(%{"user_id" => user_id, "expense_id" => expense_id}, _session, socket) do
    expense = Expenses.get_expense_for_edit!(expense_id)
    form = expense |> Expenses.change_expense(%{}) |> to_form()
    user_options = Users.list_users() |> Enum.map(fn user -> {user.name, user.id} end)

    currency_options = Currencies.list_currency_options_for_user(user_id)

    socket =
      socket
      |> assign(:expense, expense)
      |> assign(:expense_id, expense_id)
      |> assign(:form, form)
      |> assign(:user_options, user_options)
      |> assign(:currency_options, currency_options)
      |> assign(:user_id, user_id)

    {:ok, socket}
  end

  def handle_event("validate", %{"expense" => expense_attrs}, socket) do
    %{expense: expense} = socket.assigns
    form = expense |> Expenses.change_expense(expense_attrs) |> to_form(action: :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"expense" => expense_attrs}, socket) do
    %{expense: expense, user_id: user_id} = socket.assigns

    case Expenses.update_expense(expense, expense_attrs) do
      {:ok, _expense} ->
        {:noreply,
         socket
         |> put_flash(:info, "Expense updated successfully!")
         |> redirect(to: ~p"/users/#{user_id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={QuentaWeb.ExpensesLive.FormComponent}
      id={:edit_expense_form}
      action={:edit}
      user_id={@user_id}
      form={@form}
      expense={@expense}
      expense_id={@expense_id}
      user_options={@user_options}
      currency_options={@currency_options}
    />
    """
  end
end
