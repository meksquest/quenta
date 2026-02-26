defmodule QuentaWeb.UserLiveTest do
  use QuentaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias Quenta.PubSub
  alias Quenta.Users

  setup do
    george = Users.get_user!(1)
    meks = Users.get_user!(2)

    %{george: george, meks: meks}
  end

  describe "UserLive" do
    test "displays user welcome message", %{conn: conn, meks: meks} do
      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Welcome back, Meks!"
      assert html =~ "Quenta"
    end

    test "displays logout button and handles logout", %{conn: conn, meks: meks} do
      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Logout"

      view |> element("button", "Logout") |> render_click()

      assert_redirected(view, ~p"/")
    end

    test "displays add expense button", %{conn: conn, meks: meks} do
      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Add Expense"
      assert html =~ ~p"/users/#{meks.id}/expenses/new"
    end

    test "edit link navigates to expense edit page", %{conn: conn, george: george, meks: meks} do
      expense =
        insert(:expense,
          description: "Edit Me",
          amount_cents: 1200,
          date: ~D[2023-10-02],
          user: george
        )

      {:ok, view, _html} = live(conn, ~p"/users/#{meks.id}")

      view
      |> element("a[href='#{~p"/users/#{meks.id}/expenses/#{expense.id}/edit"}']", "Edit")
      |> render_click()

      assert_redirected(view, ~p"/users/#{meks.id}/expenses/#{expense.id}/edit")
    end

    test "displays empty state when no expenses", %{conn: conn, meks: meks} do
      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "No expenses yet"
      assert html =~ "Add your first expense to get started!"
    end

    test "displays expenses with correct information", %{conn: conn, george: george, meks: meks} do
      # Create an expense paid by George
      expense =
        insert(:expense,
          description: "Coffee Shop",
          amount_cents: 1050,
          date: ~D[2023-10-02],
          user: george
        )

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      # Check expense details are displayed
      assert html =~ "Coffee Shop"
      assert html =~ "USD $10.50"
      assert html =~ "Oct 2, 2023"
      assert html =~ "Paid by George"

      # Check emoji is displayed (coffee emoji for coffee-related expense)
      assert html =~ "☕"

      # Verify the expense element exists
      assert has_element?(view, "[data-testid='expense-#{expense.id}']") ||
               has_element?(view, "div", "Coffee Shop")
    end

    test "displays correct balance when user owes money", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      # George pays $20, so Meks owes George $10
      insert(:expense,
        description: "Dinner",
        amount_cents: 2000,
        date: ~D[2023-10-02],
        user: george
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # Meks should owe George money
      assert html =~ "You owe George USD $10.00"
      assert html =~ "You owe USD $10.00"
    end

    test "displays correct balance when user is owed money", %{conn: conn, meks: meks} do
      # Meks pays $30, so George owes Meks $15
      insert(:expense,
        description: "Groceries",
        amount_cents: 3000,
        date: ~D[2023-10-02],
        user: meks
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # George should owe Meks money
      assert html =~ "George owes you USD $15.00"
      assert html =~ "You lent USD $15.00"
    end

    test "displays running total correctly with multiple expenses", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      # George pays $20 (Meks owes $10)
      insert(:expense,
        description: "Dinner",
        amount_cents: 2000,
        date: ~D[2023-10-01],
        user: george
      )

      # Meks pays $30 (George owes $15)
      insert(:expense,
        description: "Groceries",
        amount_cents: 3000,
        date: ~D[2023-10-02],
        user: meks
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # Net: Meks owes $10, George owes $15, so George owes Meks $5
      assert html =~ "George owes you USD $5.00"
    end

    test "displays current balances for multiple currencies", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      insert(:expense,
        description: "Dinner USD",
        amount_cents: 2000,
        date: ~D[2023-10-01],
        user: george,
        currency_code: "USD"
      )

      insert(:expense,
        description: "Groceries NZD",
        amount_cents: 3000,
        date: ~D[2023-10-02],
        user: meks,
        currency_code: "NZD"
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "You owe George USD $10.00"
      assert html =~ "George owes you NZD $15.00"
    end

    test "displays expense items when present", %{conn: conn, george: george, meks: meks} do
      # Create expense with items
      expense =
        insert(:expense,
          description: "Restaurant Bill",
          amount_cents: 5000,
          date: ~D[2023-10-02],
          user: george
        )

      insert(:expense_item,
        description: "Pizza",
        amount_cents: 2500,
        user: george,
        expense: expense
      )

      insert(:expense_item,
        description: "Salad",
        amount_cents: 2500,
        user: meks,
        expense: expense
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # Check that expense items are displayed
      assert html =~ "Pizza (George)"
      assert html =~ "Salad (Meks)"
      assert html =~ "USD $25.00"
    end

    test "displays correct emoji for different expense types", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      expense_types = [
        {"Grocery Store", "🛒"},
        {"Italian Restaurant", "🍝"},
        {"Uber Ride", "🚗"},
        {"Coffee Shop", "☕"},
        {"Gas Station", "⛽"},
        {"Movie Theater", "🎬"},
        {"Bar Drinks", "🍺"},
        {"Random Expense", "💰"}
      ]

      for {description, _} <- expense_types do
        insert(:expense,
          description: description,
          amount_cents: 1000,
          date: ~D[2023-10-02],
          user: george
        )
      end

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      for {_description, expected_emoji} <- expense_types do
        assert html =~ expected_emoji
      end
    end

    test "displays even balance correctly", %{conn: conn, meks: meks} do
      expense =
        insert(:expense,
          description: "Personal Bill",
          amount_cents: 2000,
          date: ~D[2023-10-02],
          user: meks
        )

      insert(:expense_item,
        description: "Item 1",
        amount_cents: 1000,
        user: meks,
        expense: expense
      )

      insert(:expense_item,
        description: "Item 2",
        amount_cents: 1000,
        user: meks,
        expense: expense
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Even USD $0.00"
    end

    test "deletes an expense from the list", %{conn: conn, george: george, meks: meks} do
      expense =
        insert(:expense,
          description: "Deletable Expense",
          amount_cents: 1200,
          date: ~D[2023-10-02],
          user: george
        )

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Deletable Expense"

      view
      |> element("button[phx-click='delete_expense'][phx-value-id='#{expense.id}']")
      |> render_click()

      updated_html = render(view)

      refute updated_html =~ "Deletable Expense"
    end
  end

  describe "UserLive PubSub functionality" do
    test "updates expenses when new expense is added via PubSub", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      # Initially no expenses
      assert html =~ "No expenses yet"

      # Create a new expense (this should trigger PubSub)
      expense =
        insert(:expense,
          description: "New Coffee",
          amount_cents: 500,
          date: ~D[2023-10-02],
          user: george
        )

      # Manually trigger the PubSub message to simulate real behavior
      PubSub.broadcast_expense_added(expense)

      # Get updated HTML
      updated_html = render(view)

      # Verify the new expense appears
      assert updated_html =~ "New Coffee"
      assert updated_html =~ "USD $5.00"
      assert updated_html =~ "You owe USD $2.50"
      refute updated_html =~ "No expenses yet"
    end

    test "keeps expenses sorted by date after PubSub add", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      insert(:expense,
        description: "Newer Expense",
        amount_cents: 1000,
        date: ~D[2023-10-02],
        user: george
      )

      {:ok, view, _html} = live(conn, ~p"/users/#{meks.id}")

      older_expense =
        insert(:expense,
          description: "Older Expense",
          amount_cents: 900,
          date: ~D[2023-10-01],
          user: george
        )

      PubSub.broadcast_expense_added(older_expense)

      updated_html = render(view)

      assert updated_html =~ "Newer Expense"
      assert updated_html =~ "Older Expense"

      {newer_index, _} = :binary.match(updated_html, "Newer Expense")
      {older_index, _} = :binary.match(updated_html, "Older Expense")
      assert newer_index < older_index
    end

    test "updates running total when new expense is added via PubSub", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      # Start with one expense
      insert(:expense,
        description: "Initial Expense",
        amount_cents: 1000,
        date: ~D[2023-10-01],
        user: george
      )

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      # Check initial balance
      assert html =~ "You owe George USD $5.00"

      # Add another expense
      expense =
        insert(:expense,
          description: "Second Expense",
          amount_cents: 2000,
          date: ~D[2023-10-02],
          user: george
        )

      # Manually trigger the PubSub message to simulate real behavior
      PubSub.broadcast_expense_added(expense)
      updated_html = render(view)

      # Running total should be updated ($5 + $10 = $15)
      assert updated_html =~ "You owe George USD $15.00"
    end

    test "subscribes to expense_added on mount", %{conn: conn, george: george, meks: meks} do
      # This test verifies that the LiveView subscribes to PubSub on mount
      # We can test this by checking that the process receives messages

      {:ok, view, _html} = live(conn, ~p"/users/#{meks.id}")

      # Create an expense and broadcast it
      expense =
        insert(:expense,
          description: "Test Expense",
          amount_cents: 1500,
          date: ~D[2023-10-02],
          user: george
        )

      # Broadcast the expense_added event
      PubSub.broadcast_expense_added(expense)

      updated_html = render(view)

      assert updated_html =~ "Test Expense"
      assert updated_html =~ "USD $15.00"
    end

    test "updates expenses when expense is updated via PubSub", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      expense =
        insert(:expense,
          description: "Old Name",
          amount_cents: 1200,
          date: ~D[2023-10-03],
          user: george
        )

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Old Name"
      assert html =~ "USD $12.00"

      {1, _} =
        Quenta.Repo.update_all(
          from(e in Quenta.Expenses.Expense, where: e.id == ^expense.id),
          set: [
            description: "Updated Name",
            amount_cents: 4500,
            date: ~D[2023-10-04],
            user_id: george.id
          ]
        )

      updated_expense = Quenta.Repo.get!(Quenta.Expenses.Expense, expense.id)

      PubSub.broadcast_expense_updated(updated_expense)

      updated_html = render(view)

      assert updated_html =~ "Updated Name"
      assert updated_html =~ "USD $45.00"
      refute updated_html =~ "Old Name"
    end

    test "updates expenses when expense is deleted via PubSub", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      expense =
        insert(:expense,
          description: "Deleted Expense",
          amount_cents: 800,
          date: ~D[2023-10-03],
          user: george
        )

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Deleted Expense"

      PubSub.broadcast_expense_deleted(expense)

      updated_html = render(view)

      refute updated_html =~ "Deleted Expense"
    end
  end

  describe "UserLive error cases" do
    test "handles non-existent user", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/users/999")
      end
    end

    test "handles malformed expense data gracefully", %{conn: conn, george: george, meks: meks} do
      {:ok, view, _html} = live(conn, ~p"/users/#{meks.id}")

      # Create a mock expense with missing data and send via PubSub
      incomplete_expense = %{
        id: 999,
        description: nil,
        amount_dollars: nil,
        date: nil,
        user_id: george.id
      }

      # This should not crash the LiveView
      send(view.pid, {:expense_added, incomplete_expense})
      :timer.sleep(100)

      # LiveView should still be responsive
      assert render(view) =~ "Quenta"
    end
  end

  describe "UserLive helper functions" do
    test "formats dates correctly", %{conn: conn, george: george, meks: meks} do
      insert(:expense,
        description: "Date Test",
        amount_cents: 1000,
        date: ~D[2023-12-25],
        user: george
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Dec 25, 2023"
    end

    test "formats currency correctly", %{conn: conn, george: george, meks: meks} do
      insert(:expense,
        description: "Currency Test",
        amount_cents: 12345,
        date: ~D[2023-10-02],
        user: george
      )

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "USD $123.45"
    end
  end
end
