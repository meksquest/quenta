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
    expense_attrs = apply_defaults(expense_attrs, expense)
    form = expense |> Expenses.change_expense(expense_attrs) |> to_form(action: :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"expense" => expense_attrs}, socket) do
    %{expense: expense, user_id: user_id} = socket.assigns
    expense_attrs = apply_defaults(expense_attrs, expense)

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

  defp apply_defaults(expense_attrs, expense) do
    expense_attrs
    |> Map.put_new("created_by_user_id", expense.created_by_user_id)
    |> Map.put_new("paid_by_user_id", expense.paid_by_user_id || expense.created_by_user_id)
    |> Map.put_new(
      "participants_user_ids",
      expense.participants_user_ids || [expense.created_by_user_id]
    )
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 text-white">
      <!-- Header -->
      <div class="bg-slate-800 border-b border-slate-700">
        <div class="max-w-4xl mx-auto px-4 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-white">Edit Expense</h1>
              <p class="text-slate-300 mt-1">Update the expense and its line items</p>
            </div>
            <.link
              navigate={~p"/users/#{@user_id}"}
              class="inline-flex items-center gap-2 rounded-md border border-slate-500 bg-transparent px-3 py-2 text-sm font-medium text-slate-200 hover:bg-slate-700 hover:text-white focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 focus:ring-offset-slate-900"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
            </.link>
          </div>
        </div>
      </div>

      <div class="max-w-4xl mx-auto px-4 py-8">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-8">
          <!-- Main Expense Details Card -->
          <div class="bg-slate-800 rounded-lg border border-slate-700 shadow-sm">
            <div class="p-6">
              <div class="flex items-center gap-3 mb-6">
                <div class="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
                  <.icon name="hero-receipt-percent" class="w-5 h-5 text-white" />
                </div>
                <h2 class="text-lg font-semibold text-white">Expense Details</h2>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="md:col-span-2">
                  <label
                    for={@form[:description].id}
                    class="block text-sm font-medium text-slate-200 mb-2"
                  >
                    Description *
                  </label>
                  <.input
                    type="text"
                    field={@form[:description]}
                    placeholder="Enter expense description..."
                  />
                </div>

                <div>
                  <label
                    for={@form[:currency_code].id}
                    class="block text-sm font-medium text-slate-200 mb-2"
                  >
                    Currency *
                  </label>
                  <.live_component
                    module={QuentaWeb.CurrencySelectComponent}
                    id={@form[:currency_code].id <> "-currency-select"}
                    field={@form[:currency_code]}
                    options={@currency_options}
                  />
                </div>

                <div>
                  <label
                    for={@form[:amount_dollars].id}
                    class="block text-sm font-medium text-slate-200 mb-2"
                  >
                    Total Amount *
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <span class="text-slate-400 sm:text-sm">$</span>
                    </div>
                    <.input
                      type="number"
                      field={@form[:amount_dollars]}
                      step="0.01"
                      min="0"
                      max="21474836"
                      placeholder="0.00"
                      class="pl-6"
                    />
                  </div>
                </div>

                <div>
                  <label for={@form[:date].id} class="block text-sm font-medium text-slate-200 mb-2">
                    Date *
                  </label>
                  <.input
                    type="date"
                    field={@form[:date]}
                    value={@form[:date].value || Date.utc_today() |> Date.to_iso8601()}
                  />
                </div>

                <div>
                  <label
                    for={@form[:created_by_user_id].id <> "-display"}
                    class="block text-sm font-medium text-slate-200 mb-2"
                  >
                    Created By *
                  </label>
                  <.input
                    type="select"
                    field={@form[:created_by_user_id]}
                    id={@form[:created_by_user_id].id <> "-display"}
                    options={@user_options}
                    value={@form[:created_by_user_id].value || @user_id}
                    disabled
                  />
                  <p class="text-xs text-slate-500 mt-2">
                    This is set when the expense is created.
                  </p>
                </div>

                <input
                  type="hidden"
                  name={@form[:created_by_user_id].name}
                  value={@form[:created_by_user_id].value || @user_id}
                />
              </div>
            </div>
          </div>
          
    <!-- Participants & Payer Section -->
          <div class="bg-slate-800 rounded-lg border border-slate-700 shadow-sm">
            <div class="p-6">
              <div class="flex items-center gap-3 mb-6">
                <div class="w-10 h-10 bg-purple-600 rounded-lg flex items-center justify-center">
                  <.icon name="hero-user-group" class="w-5 h-5 text-white" />
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-white">Participants & Payer</h2>
                  <p class="text-sm text-slate-400">
                    Shares are calculated automatically from items, then split evenly.
                  </p>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <div class="block text-sm font-medium text-slate-200 mb-2">
                    Participants *
                  </div>
                  <div class="space-y-2">
                    <%= for {user_name, user_id} <- @user_options do %>
                      <label class="flex items-center gap-2 text-sm text-slate-200">
                        <input
                          type="checkbox"
                          name="expense[participants_user_ids][]"
                          value={user_id}
                          checked={
                            Enum.member?(
                              @form[:participants_user_ids].value ||
                                [@form[:created_by_user_id].value || @user_id],
                              user_id
                            )
                          }
                          class="rounded border-slate-500 bg-slate-700 text-blue-500 focus:ring-2 focus:ring-blue-500"
                        />
                        <span>{user_name}</span>
                      </label>
                    <% end %>
                  </div>
                  <p class="text-xs text-slate-500 mt-2">
                    Item owners are included automatically even if not selected.
                  </p>
                </div>

                <div>
                  <label
                    for={@form[:paid_by_user_id].id}
                    class="block text-sm font-medium text-slate-200 mb-2"
                  >
                    Paid By *
                  </label>
                  <.input
                    type="select"
                    field={@form[:paid_by_user_id]}
                    options={@user_options}
                    value={
                      @form[:paid_by_user_id].value || @form[:created_by_user_id].value || @user_id
                    }
                  />
                  <p class="text-xs text-slate-500 mt-2">
                    Payments are recorded as a single payer for now.
                  </p>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Expense Items Section -->
          <div class="bg-slate-800 rounded-lg border border-slate-700 shadow-sm">
            <div class="p-6">
              <div class="flex items-center justify-between mb-6">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 bg-green-600 rounded-lg flex items-center justify-center">
                    <.icon name="hero-list-bullet" class="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <h2 class="text-lg font-semibold text-white">Expense Items</h2>
                    <p class="text-sm text-slate-400">Break down the expense into individual items</p>
                  </div>
                </div>
                <button
                  type="button"
                  name="expense[expense_items_sort][]"
                  value="new"
                  phx-click={JS.dispatch("change")}
                  class="inline-flex items-center gap-2 rounded-md bg-green-600 px-3 py-2 text-sm font-semibold text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 focus:ring-offset-slate-900 transition-colors"
                >
                  <.icon name="hero-plus" class="w-4 h-4" /> Add Item
                </button>
              </div>

              <input type="hidden" name="expense[expense_items_drop][]" />

              <div class="space-y-4">
                <.inputs_for :let={eif} field={@form[:expense_items]}>
                  <input type="hidden" name="expense[expense_items_sort][]" value={eif.index} />
                  <input type="hidden" id={eif[:id].id} name={eif[:id].name} value={eif[:id].value} />

                  <div class="bg-slate-700 rounded-lg border border-slate-600 p-4 relative group">
                    <!-- Remove Button -->
                    <button
                      type="button"
                      name="expense[expense_items_drop][]"
                      value={eif.index}
                      phx-click={JS.dispatch("change")}
                      class="absolute top-3 right-3 p-1 rounded-md text-slate-400 hover:text-red-400 hover:bg-red-900/20 transition-colors opacity-0 group-hover:opacity-100"
                      title="Remove this item"
                    >
                      <.icon name="hero-x-mark" class="w-5 h-5" />
                    </button>

                    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 pr-10">
                      <div>
                        <label
                          for={eif[:description].id}
                          class="block text-sm font-medium text-slate-200 mb-2"
                        >
                          Item Description *
                        </label>
                        <.input
                          type="text"
                          field={eif[:description]}
                          placeholder="What was purchased?"
                        />
                      </div>

                      <div>
                        <label
                          for={eif[:amount_dollars].id}
                          class="block text-sm font-medium text-slate-200 mb-2"
                        >
                          Amount *
                        </label>
                        <div class="relative">
                          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <span class="text-slate-400 sm:text-sm">$</span>
                          </div>
                          <.input
                            type="number"
                            field={eif[:amount_dollars]}
                            step="0.01"
                            min="0"
                            placeholder="0.00"
                            class="pl-6"
                          />
                        </div>
                      </div>

                      <div>
                        <label
                          for={eif[:user_id].id}
                          class="block text-sm font-medium text-slate-200 mb-2"
                        >
                          Bought By *
                        </label>
                        <.input
                          id={eif[:user_id].id}
                          name={eif[:user_id].name}
                          type="select"
                          options={@user_options}
                          prompt="Select person…"
                          value={eif[:user_id].value}
                        />
                      </div>
                    </div>
                  </div>
                </.inputs_for>
                
    <!-- Empty State -->
                <%= if Enum.empty?(@form[:expense_items].value || []) do %>
                  <div class="text-center py-8 border-2 border-dashed border-slate-600 rounded-lg">
                    <.icon name="hero-list-bullet" class="w-12 h-12 text-slate-500 mx-auto mb-3" />
                    <p class="text-slate-400 text-sm">No expense items added yet</p>
                    <p class="text-slate-500 text-xs mt-1">
                      Click "Add Item" to break down your expense
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Action Buttons -->
          <div class="flex flex-col sm:flex-row gap-3 sm:justify-end">
            <.link
              navigate={~p"/users/#{@user_id}"}
              class="inline-flex items-center justify-center gap-2 rounded-lg border border-slate-600 bg-transparent px-4 py-2 text-sm font-medium text-slate-300 hover:bg-slate-700 hover:text-white focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 focus:ring-offset-slate-900 transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              disabled={!@form.source.valid?}
              class={[
                "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-slate-900 transition-colors",
                if(@form.source.valid?,
                  do: "bg-blue-600 hover:bg-blue-700",
                  else: "bg-slate-600 cursor-not-allowed"
                )
              ]}
            >
              <.icon name="hero-check" class="w-4 h-4" />
              {if @form.source.valid?, do: "Update Expense", else: "Please Fix Errors"}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
