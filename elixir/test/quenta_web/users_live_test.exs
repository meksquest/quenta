defmodule QuentaWeb.UserLiveTest do
  use QuentaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Quenta.Users
  alias Quenta.Expenses
  alias Quenta.PubSub

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

    test "displays empty state when no expenses", %{conn: conn, meks: meks} do
      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "No expenses yet"
      assert html =~ "Add your first expense to get started!"
    end

    test "displays expenses with correct information", %{conn: conn, george: george, meks: meks} do
      # Create an expense paid by George
      params = %{
        "description" => "Coffee Shop",
        "amount_dollars" => 10.50,
        "date" => ~D[2023-10-02],
        "user_id" => george.id
      }

      {:ok, expense} = Expenses.create_expense(params)

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      # Check expense details are displayed
      assert html =~ "Coffee Shop"
      assert html =~ "$10.50"
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
      params = %{
        "description" => "Dinner",
        "amount_dollars" => 20.00,
        "date" => ~D[2023-10-02],
        "user_id" => george.id
      }

      {:ok, _expense} = Expenses.create_expense(params)

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # Meks should owe George money
      assert html =~ "You owe George $10.00"
      assert html =~ "You owe $10.00"
    end

    test "displays correct balance when user is owed money", %{conn: conn, meks: meks} do
      # Meks pays $30, so George owes Meks $15
      params = %{
        "description" => "Groceries",
        "amount_dollars" => 30.00,
        "date" => ~D[2023-10-02],
        "user_id" => meks.id
      }

      {:ok, _expense} = Expenses.create_expense(params)

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # George should owe Meks money
      assert html =~ "George owes you $15.00"
      assert html =~ "You lent $15.00"
    end

    test "displays running total correctly with multiple expenses", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      # George pays $20 (Meks owes $10)
      {:ok, _expense1} =
        Expenses.create_expense(%{
          "description" => "Dinner",
          "amount_dollars" => 20.00,
          "date" => ~D[2023-10-01],
          "user_id" => george.id
        })

      # Meks pays $30 (George owes $15)
      {:ok, _expense2} =
        Expenses.create_expense(%{
          "description" => "Groceries",
          "amount_dollars" => 30.00,
          "date" => ~D[2023-10-02],
          "user_id" => meks.id
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # Net: Meks owes $10, George owes $15, so George owes Meks $5
      assert html =~ "George owes you $5.00"
    end

    test "displays expense items when present", %{conn: conn, george: george, meks: meks} do
      # Create expense with items
      {:ok, _expense} =
        Expenses.create_expense(%{
          "description" => "Restaurant Bill",
          "amount_dollars" => 50.00,
          "date" => ~D[2023-10-02],
          "user_id" => george.id,
          "expense_items" => [
            %{
              "description" => "Pizza",
              "amount_dollars" => 25.00,
              "user_id" => george.id
            },
            %{
              "description" => "Salad",
              "amount_dollars" => 25.00,
              "user_id" => meks.id
            }
          ]
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      # Check that expense items are displayed
      assert html =~ "Pizza (George)"
      assert html =~ "Salad (Meks)"
      assert html =~ "$25.00"
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
        {:ok, _expense} =
          Expenses.create_expense(%{
            "description" => description,
            "amount_dollars" => 10.00,
            "date" => ~D[2023-10-02],
            "user_id" => george.id
          })
      end

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      for {_description, expected_emoji} <- expense_types do
        assert html =~ expected_emoji
      end
    end

    test "displays even balance correctly", %{conn: conn, meks: meks} do
      {:ok, _expense} =
        Expenses.create_expense(%{
          "description" => "Personal Bill",
          "amount_dollars" => 20.00,
          "date" => ~D[2023-10-02],
          "user_id" => meks.id,
          "expense_items" => [
            %{
              "description" => "Item 1",
              "amount_dollars" => 10.00,
              "user_id" => meks.id
            },
            %{
              "description" => "Item 2",
              "amount_dollars" => 10.00,
              "user_id" => meks.id
            }
          ]
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Even $0.00"
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
      params = %{
        "description" => "New Coffee",
        "amount_dollars" => 5.00,
        "date" => ~D[2023-10-02],
        "user_id" => george.id
      }

      {:ok, expense} = Expenses.create_expense(params)

      # Manually trigger the PubSub message to simulate real behavior
      PubSub.broadcast_expense_added(expense)

      # Get updated HTML
      updated_html = render(view)

      # Verify the new expense appears
      assert updated_html =~ "New Coffee"
      assert updated_html =~ "$5.00"
      assert updated_html =~ "You owe $2.50"
      refute updated_html =~ "No expenses yet"
    end

    test "updates running total when new expense is added via PubSub", %{
      conn: conn,
      george: george,
      meks: meks
    } do
      # Start with one expense
      {:ok, _initial_expense} =
        Expenses.create_expense(%{
          "description" => "Initial Expense",
          "amount_dollars" => 10.00,
          "date" => ~D[2023-10-01],
          "user_id" => george.id
        })

      {:ok, view, html} = live(conn, ~p"/users/#{meks.id}")

      # Check initial balance
      assert html =~ "You owe George $5.00"

      # Add another expense
      {:ok, _new_expense} =
        Expenses.create_expense(%{
          "description" => "Second Expense",
          "amount_dollars" => 20.00,
          "date" => ~D[2023-10-02],
          "user_id" => george.id
        })

      updated_html = render(view)

      # Running total should be updated ($5 + $10 = $15)
      assert updated_html =~ "You owe George $15.00"
    end

    test "subscribes to expense_added on mount", %{conn: conn, meks: meks} do
      # This test verifies that the LiveView subscribes to PubSub on mount
      # We can test this by checking that the process receives messages

      {:ok, view, _html} = live(conn, ~p"/users/#{meks.id}")

      # Create an expense and broadcast it
      {:ok, expense} =
        Expenses.create_expense(%{
          "description" => "Test Expense",
          "amount_dollars" => 15.00,
          "date" => ~D[2023-10-02],
          "user_id" => 1
        })

      # Broadcast the expense_added event
      PubSub.broadcast_expense_added(expense)

      updated_html = render(view)

      assert updated_html =~ "Test Expense"
      assert updated_html =~ "$15.00"
    end
  end

  describe "UserLive error cases" do
    test "handles non-existent user", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/users/999")
      end
    end

    test "handles malformed expense data gracefully", %{conn: conn, meks: meks} do
      {:ok, view, _html} = live(conn, ~p"/users/#{meks.id}")

      # Create a mock expense with missing data and send via PubSub
      incomplete_expense = %{
        id: 999,
        description: nil,
        amount_dollars: nil,
        date: nil,
        user_id: 1
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
      {:ok, _expense} =
        Expenses.create_expense(%{
          "description" => "Date Test",
          "amount_dollars" => 10.00,
          "date" => ~D[2023-12-25],
          "user_id" => george.id
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "Dec 25, 2023"
    end

    test "formats currency correctly", %{conn: conn, george: george, meks: meks} do
      {:ok, _expense} =
        Expenses.create_expense(%{
          "description" => "Currency Test",
          "amount_dollars" => 123.45,
          "date" => ~D[2023-10-02],
          "user_id" => george.id
        })

      {:ok, _view, html} = live(conn, ~p"/users/#{meks.id}")

      assert html =~ "$123.45"
    end
  end
end
