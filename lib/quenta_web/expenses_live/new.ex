defmodule QuentaWeb.ExpensesLive.New do
  use QuentaWeb, :live_view

  alias Quenta.Expenses
  alias Quenta.Expenses.Expense
  alias Quenta.Users
  alias Quenta.Currencies

  def mount(%{"user_id" => user_id}, _session, socket) do
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

  def render(assigns) do
    ~H"""
    <.live_component
      module={QuentaWeb.ExpensesLive.FormComponent}
      id={:new_expense_form}
      action={:new}
      user_id={@user_id}
      form={@form}
      user_options={@user_options}
      currency_options={@currency_options}
    />
    """
  end
end
