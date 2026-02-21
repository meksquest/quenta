defmodule QuentaWeb.ExpensesLive.EditTest do
  use QuentaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quenta.Users

  setup do
    %{george: Users.get_user!(1), meks: Users.get_user!(2)}
  end

  test "renders edit expense form with existing values", %{conn: conn, george: george} do
    expense =
      insert(:expense,
        description: "Lunch",
        amount_cents: 2500,
        date: ~D[2023-10-01],
        user: george
      )

    {:ok, view, _html} = live(conn, ~p"/users/#{george.id}/expenses/#{expense.id}/edit")

    html = render(view)

    assert html =~ "Edit Expense"
    assert html =~ "Description"
    assert html =~ "Amount"
    assert html =~ "Date"
    assert html =~ "Currency"
    assert html =~ "Paid By"
    assert html =~ "Lunch"
    assert html =~ "value=\"Lunch\""
    assert html =~ "value=\"25.00\""
    assert html =~ "value=\"2023-10-01\""
    assert html =~ "value=\"USD\""
  end

  test "updates an expense", %{conn: conn, george: george} do
    expense =
      insert(:expense,
        description: "Old Expense",
        amount_cents: 1000,
        date: ~D[2023-10-01],
        user: george
      )

    {:ok, view, _html} = live(conn, ~p"/users/#{george.id}/expenses/#{expense.id}/edit")

    result =
      view
      |> element("form")
      |> render_submit(%{
        expense: %{
          amount_dollars: "42.00",
          description: "Updated Expense",
          user_id: george.id,
          date: "2023-10-02",
          currency_code: "EUR"
        }
      })

    updated_expense = Quenta.Expenses.get_expense!(expense.id)
    assert updated_expense.description == "Updated Expense"
    assert updated_expense.amount_cents == 4_200
    assert updated_expense.date == ~D[2023-10-02]
    assert updated_expense.currency_code == "EUR"

    {:ok, conn} = follow_redirect(result, conn, ~p"/users/#{george.id}")
    assert conn.resp_body =~ "Updated Expense"
    assert conn.resp_body =~ "$42.00"
  end

  test "displays validation errors on update", %{conn: conn, george: george} do
    expense =
      insert(:expense,
        description: "Old Expense",
        amount_cents: 1000,
        date: ~D[2023-10-01],
        user: george
      )

    {:ok, view, _html} = live(conn, ~p"/users/#{george.id}/expenses/#{expense.id}/edit")

    view
    |> element("form")
    |> render_submit(%{
      expense: %{
        amount_dollars: "",
        description: "",
        user_id: "",
        date: "",
        currency_code: ""
      }
    })

    assert render(view) =~ "can&#39;t be blank"
  end

  test "updates an expense with expense items", %{conn: conn, george: george, meks: meks} do
    expense =
      insert(:expense,
        description: "Dinner",
        amount_cents: 5000,
        date: ~D[2023-10-01],
        user: george
      )

    item =
      insert(:expense_item,
        description: "Old Item",
        amount_cents: 1500,
        user: george,
        expense: expense
      )

    {:ok, view, _html} = live(conn, ~p"/users/#{george.id}/expenses/#{expense.id}/edit")

    result =
      view
      |> element("form")
      |> render_submit(%{
        expense: %{
          amount_dollars: "100.00",
          description: "Updated Dinner",
          user_id: george.id,
          date: "2023-10-02",
          currency_code: "EUR",
          expense_items: %{
            "0" => %{
              id: item.id,
              description: "Updated Item",
              amount_dollars: "25.00",
              user_id: george.id
            },
            "1" => %{
              description: "New Item",
              amount_dollars: "30.00",
              user_id: meks.id
            }
          }
        }
      })

    updated_expense = Quenta.Expenses.get_expense!(expense.id, preloads: [:expense_items])
    assert updated_expense.description == "Updated Dinner"
    assert updated_expense.amount_cents == 10_000
    assert updated_expense.date == ~D[2023-10-02]
    assert updated_expense.currency_code == "EUR"

    assert Enum.any?(
             updated_expense.expense_items,
             &(&1.description == "Updated Item" && &1.amount_cents == 2_500 &&
                 &1.user_id == george.id)
           )

    assert Enum.any?(
             updated_expense.expense_items,
             &(&1.description == "New Item" && &1.amount_cents == 3_000 && &1.user_id == meks.id)
           )

    {:ok, conn} = follow_redirect(result, conn, ~p"/users/#{george.id}")
    assert conn.resp_body =~ "Updated Dinner"
    assert conn.resp_body =~ "$100.00"
    assert conn.resp_body =~ "Updated Item"
    assert conn.resp_body =~ "$25.00"
    assert conn.resp_body =~ "New Item"
    assert conn.resp_body =~ "$30.00"
  end

  test "displays validation errors for expense items on update", %{conn: conn, george: george} do
    expense =
      insert(:expense,
        description: "Dinner",
        amount_cents: 5000,
        date: ~D[2023-10-01],
        user: george
      )

    item =
      insert(:expense_item,
        description: "Old Item",
        amount_cents: 1500,
        user: george,
        expense: expense
      )

    {:ok, view, _html} = live(conn, ~p"/users/#{george.id}/expenses/#{expense.id}/edit")

    view
    |> element("form")
    |> render_submit(%{
      expense: %{
        amount_dollars: "100.00",
        description: "Updated Dinner",
        user_id: george.id,
        date: "2023-10-02",
        currency_code: "",
        expense_items: %{
          "0" => %{
            id: item.id,
            description: "",
            amount_dollars: "",
            user_id: ""
          }
        }
      }
    })

    assert render(view) =~ "can&#39;t be blank"
  end
end
