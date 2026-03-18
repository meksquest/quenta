defmodule QuentaWeb.UserLive do
  use QuentaWeb, :live_view

  import Quenta.Currency

  alias Quenta.ExpenseCalculator
  alias Quenta.Expenses
  alias Quenta.PubSub
  alias Quenta.Users

  @impl Phoenix.LiveView
  def mount(%{"user_id" => user_id}, _session, socket) do
    PubSub.subscribe_to_expense_added()
    PubSub.subscribe_to_expense_updated()
    PubSub.subscribe_to_expense_deleted()
    user = Users.get_user!(user_id)
    # Preload both created_by_user and expense_items with their associated users
    expenses = Expenses.list_expenses(preloads: [:created_by_user, expense_items: [:user]])

    # Get all users for calculations
    all_users = Users.list_users()
    other_user = Enum.find(all_users, fn u -> u.id != user.id end)

    # Calculate balances for each expense
    expenses_with_balances = calculate_expenses_with_balances(expenses, all_users, user.id)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:other_user, other_user)
      |> assign(:all_users, all_users)
      |> assign(:expenses, expenses_with_balances)
      |> assign(
        :running_totals_by_currency,
        calculate_running_totals_by_currency(expenses_with_balances)
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("logout", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl Phoenix.LiveView
  def handle_event("delete_expense", %{"id" => id}, socket) do
    %{expenses: expenses, user: user, all_users: all_users} = socket.assigns
    expense_id = String.to_integer(id)
    expense = Expenses.get_expense!(expense_id)

    case Expenses.delete_expense(expense) do
      {:ok, _} ->
        updated_expenses = Enum.reject(expenses, &(&1.id == expense.id))
        sorted_expenses = sort_expenses_by_date(updated_expenses)

        expenses_with_balances =
          calculate_expenses_with_balances(sorted_expenses, all_users, user.id)

        {:noreply,
         socket
         |> assign(:expenses, expenses_with_balances)
         |> assign(
           :running_totals_by_currency,
           calculate_running_totals_by_currency(expenses_with_balances)
         )
         |> put_flash(:info, "Expense deleted successfully.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unable to delete expense.")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:expense_added, %Quenta.Expenses.Expense{} = expense}, socket) do
    %{expenses: expenses, all_users: all_users, user: user} = socket.assigns
    preloaded_expense = Quenta.Repo.preload(expense, [:created_by_user, expense_items: [:user]])
    updated_expenses = [preloaded_expense | expenses]
    sorted_expenses = sort_expenses_by_date(updated_expenses)

    expenses_with_balances =
      calculate_expenses_with_balances(sorted_expenses, all_users, user.id)

    socket =
      socket
      |> assign(:expenses, expenses_with_balances)
      |> assign(
        :running_totals_by_currency,
        calculate_running_totals_by_currency(expenses_with_balances)
      )

    {:noreply, socket}
  end

  def handle_info({:expense_updated, %Quenta.Expenses.Expense{} = expense}, socket) do
    %{expenses: expenses, all_users: all_users, user: user} = socket.assigns
    preloaded_expense = Quenta.Repo.preload(expense, [:created_by_user, expense_items: [:user]])

    updated_expenses =
      Enum.map(expenses, fn existing ->
        if existing.id == preloaded_expense.id, do: preloaded_expense, else: existing
      end)

    sorted_expenses = sort_expenses_by_date(updated_expenses)

    expenses_with_balances =
      calculate_expenses_with_balances(sorted_expenses, all_users, user.id)

    socket =
      socket
      |> assign(:expenses, expenses_with_balances)
      |> assign(
        :running_totals_by_currency,
        calculate_running_totals_by_currency(expenses_with_balances)
      )

    {:noreply, socket}
  end

  def handle_info({:expense_deleted, %Quenta.Expenses.Expense{} = expense}, socket) do
    %{expenses: expenses, all_users: all_users, user: user} = socket.assigns
    updated_expenses = Enum.reject(expenses, &(&1.id == expense.id))
    sorted_expenses = sort_expenses_by_date(updated_expenses)

    expenses_with_balances =
      calculate_expenses_with_balances(sorted_expenses, all_users, user.id)

    socket =
      socket
      |> assign(:expenses, expenses_with_balances)
      |> assign(
        :running_totals_by_currency,
        calculate_running_totals_by_currency(expenses_with_balances)
      )

    {:noreply, socket}
  end

  def handle_info({:expense_deleted, _}, socket), do: {:noreply, socket}
  def handle_info({:expense_updated, _}, socket), do: {:noreply, socket}
  def handle_info({:expense_added, _}, socket), do: {:noreply, socket}

  defp sort_expenses_by_date(expenses) do
    Enum.sort(expenses, fn left, right ->
      with :eq <- Date.compare(left.date, right.date),
           :eq <- NaiveDateTime.compare(left.inserted_at, right.inserted_at) do
        left.id >= right.id
      else
        :gt -> true
        :lt -> false
      end
    end)
  end

  defp calculate_expenses_with_balances(expenses, all_users, current_user_id) do
    Enum.map(expenses, fn expense ->
      # Calculate balances for this expense
      balances = ExpenseCalculator.calculate_balances(expense, expense.expense_items, all_users)

      # Find current user's balance for this expense
      current_user_balance = Enum.find(balances, &(&1.user.id == current_user_id))

      # Add balance info to expense
      Map.put(expense, :user_balance, current_user_balance.balance)
    end)
  end

  defp calculate_running_totals_by_currency(expenses_with_balances) do
    expenses_with_balances
    |> Enum.reduce(%{}, fn expense, totals ->
      currency_code = expense.currency_code || "USD"
      Map.update(totals, currency_code, expense.user_balance, &(&1 + expense.user_balance))
    end)
    |> Enum.sort_by(fn {currency_code, _} -> currency_code end)
  end

  defp format_current_balance_line(currency_code, amount_cents, _user_name, other_user_name) do
    formatted_amount = "#{currency_code} #{format_cents_to_dollars(abs(amount_cents))}"

    cond do
      amount_cents > 0 ->
        {"You owe #{other_user_name} #{formatted_amount}", "text-red-400"}

      amount_cents < 0 ->
        {"#{other_user_name} owes you #{formatted_amount}", "text-green-400"}

      true ->
        {"Even #{formatted_amount}", "text-slate-400"}
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end

  defp get_expense_emoji(description) do
    description_lower = String.downcase(description)

    cond do
      String.contains?(description_lower, ["grocery", "food", "market"]) -> "🛒"
      String.contains?(description_lower, ["dinner", "restaurant", "pizza", "italian"]) -> "🍝"
      String.contains?(description_lower, ["uber", "taxi", "ride"]) -> "🚗"
      String.contains?(description_lower, ["coffee", "cafe", "pastry"]) -> "☕"
      String.contains?(description_lower, ["gas", "fuel"]) -> "⛽"
      String.contains?(description_lower, ["movie", "cinema"]) -> "🎬"
      String.contains?(description_lower, ["drink", "bar", "beer"]) -> "🍺"
      true -> "💰"
    end
  end

  defp format_expense_balance(expense) do
    cond do
      expense.user_balance > 0 ->
        # Current user owes money
        {"You owe", format_amount_with_currency(expense, expense.user_balance), "text-red-400"}

      expense.user_balance < 0 ->
        # Current user is owed money
        {"You lent", format_amount_with_currency(expense, abs(expense.user_balance)),
         "text-green-400"}

      true ->
        # Balanced
        {"Even", format_amount_with_currency(expense, 0), "text-slate-400"}
    end
  end

  defp format_amount_with_currency(expense, amount_cents) do
    currency_code = expense.currency_code || "USD"
    "#{currency_code} #{format_cents_to_dollars(amount_cents)}"
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 text-white">
      <!-- Header -->
      <div class="bg-slate-800 border-b border-slate-700">
        <div class="max-w-4xl mx-auto px-4 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold">Quenta</h1>
              <p class="text-slate-200 capitalize">Welcome back, {@user.name}!</p>
            </div>
            <button
              phx-click="logout"
              class="inline-flex items-center gap-2 rounded-md border border-slate-500 bg-transparent px-3 py-2 text-sm font-medium text-slate-200 hover:bg-slate-700 hover:text-white focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 focus:ring-offset-slate-900"
            >
              <.icon name="hero-arrow-right-start-on-rectangle" class="w-4 h-4" /> Logout
            </button>
          </div>
        </div>
      </div>

      <div class="max-w-4xl mx-auto px-4 py-8">
        <!-- Running Total -->
        <div class="rounded-lg border border-slate-700 bg-slate-800 text-slate-200 shadow-sm mb-8">
          <div class="p-6">
            <div class="text-center">
              <h2 class="text-lg font-medium text-slate-200 mb-2">Current Balances</h2>
              <div class="space-y-2 text-lg sm:text-2xl font-bold">
                <%= if @running_totals_by_currency == [] do %>
                  <span class="text-slate-400">No balances yet</span>
                <% else %>
                  <%= for {currency_code, amount_cents} <- @running_totals_by_currency do %>
                    <% {line, color_class} =
                      format_current_balance_line(
                        currency_code,
                        amount_cents,
                        @user.name,
                        @other_user.name
                      ) %>
                    <div class={color_class}>{line}</div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Add Expense Button -->
        <div class="flex flex-col sm:flex-row sm:justify-between sm:items-center mb-6 gap-4">
          <h2 class="text-xl font-semibold">Recent Expenses</h2>
          <.link
            navigate={~p"/users/#{@user.id}/expenses/new"}
            class="inline-flex items-center gap-2 rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-slate-900"
          >
            <.icon name="hero-plus" class="w-4 h-4" /> Add Expense
          </.link>
        </div>
        
    <!-- Expenses List -->
        <div class="space-y-4">
          <%= for expense <- @expenses do %>
            <div class="rounded-lg border border-slate-700 bg-slate-800 text-slate-200 shadow-sm">
              <div class="p-4">
                <div class="flex items-start justify-between gap-4">
                  <div class="flex items-start space-x-4 min-w-0">
                    <div class="text-2xl flex-shrink-0">{get_expense_emoji(expense.description)}</div>
                    <div class="min-w-0 flex-1">
                      <h3 class="font-medium text-white truncate">{expense.description}</h3>
                      <p class="text-sm text-slate-300">{format_date(expense.date)}</p>
                    </div>
                  </div>
                  <div class="text-right flex-shrink-0">
                    <div class="font-semibold text-white">
                      {format_amount_with_currency(expense, expense.amount_cents)}
                    </div>
                    <div class="text-sm mt-1">
                      <% {label, amount, color_class} = format_expense_balance(expense) %>
                      <span class={color_class}>
                        {label} {amount}
                      </span>
                    </div>
                  </div>
                </div>
                
    <!-- Show expense items if any -->
                <%= if length(expense.expense_items) > 0 do %>
                  <div class="mt-3 space-y-1 pl-10">
                    <%= for item <- expense.expense_items do %>
                      <div class="text-xs text-slate-400 flex justify-between">
                        <span>{item.description} ({item.user.name})</span>
                        <span>
                          {format_cents_to_dollars(item.amount_cents)}
                        </span>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <div class="mt-3 flex items-center gap-3 pl-10">
                  <.link
                    navigate={~p"/users/#{@user.id}/expenses/#{expense.id}/edit"}
                    class="text-xs text-blue-300 hover:text-blue-200"
                  >
                    Edit
                  </.link>
                  <button
                    type="button"
                    phx-click="delete_expense"
                    phx-value-id={expense.id}
                    data-confirm="Delete this expense?"
                    class="text-xs text-red-300 hover:text-red-200"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%= if @expenses == [] do %>
          <div class="text-center py-12">
            <p class="text-slate-400 text-lg">No expenses yet</p>
            <p class="text-slate-500 mt-2">Add your first expense to get started!</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
