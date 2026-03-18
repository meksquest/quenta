defmodule QuentaWeb.ExpensesLive.FormComponent do
  use QuentaWeb, :live_component

  alias Quenta.Expenses
  alias Quenta.Expenses.Expense

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("validate", %{"expense" => expense_attrs}, socket) do
    form = %Expense{} |> Expenses.change_expense(expense_attrs) |> to_form(action: :validate)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"expense" => expense_attrs}, %{assigns: %{action: :new}} = socket) do
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

  def handle_event("save", %{"expense" => expense_attrs}, %{assigns: %{action: :edit}} = socket) do
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

  defp action_label(:new), do: "Create Expense"
  defp action_label(:edit), do: "Update Expense"
end
