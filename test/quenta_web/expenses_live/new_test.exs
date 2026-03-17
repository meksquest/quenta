defmodule QuentaWeb.ExpensesLive.NewTest do
  use QuentaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Quenta.Users

  setup do
    %{george: Users.get_user!(1)}
  end

  test "renders new expense form", %{conn: conn, george: george} do
    insert(:expense, created_by_user: george, currency_code: "USD")

    {:ok, view, _html} = live(conn, ~p"/users/#{george}/expenses/new")

    assert render(view) =~ "Description"
    assert render(view) =~ "Amount"
    assert render(view) =~ "Date"
    assert render(view) =~ "Currency"
    assert render(view) =~ "Recently used"
    assert render(view) =~ "All currencies"
    assert render(view) =~ "USD - United States Dollar"
  end

  test "defaults currency to the user's last used currency", %{conn: conn, george: george} do
    insert(:expense,
      created_by_user: george,
      currency_code: "EUR",
      inserted_at: ~N[2024-01-01 10:00:00]
    )

    insert(:expense,
      created_by_user: george,
      currency_code: "USD",
      inserted_at: ~N[2024-01-02 10:00:00]
    )

    {:ok, view, _html} = live(conn, ~p"/users/#{george}/expenses/new")

    html = render(view)

    hidden_input =
      html
      |> Floki.find("input[name=\"expense[currency_code]\"]")
      |> List.first()

    assert Floki.attribute(hidden_input, "value") == ["USD"]
  end

  test "creates a new expense", %{conn: conn, george: george} do
    {:ok, view, _html} = live(conn, ~p"/users/#{george}/expenses/new")

    view
    |> element("form")
    |> render_submit(%{
      expense: %{
        amount_dollars: "100.00",
        description: "Test Expense",
        created_by_user_id: george.id,
        date: "2023-10-01",
        currency_code: "USD"
      }
    })

    assert_redirected(view, ~p"/users/#{george}")
  end

  test "displays validation errors", %{conn: conn, george: george} do
    {:ok, view, _html} = live(conn, ~p"/users/#{george}/expenses/new")

    view
    |> element("form")
    |> render_submit(%{
      expense: %{
        amount_cents: "",
        description: "",
        created_by_user_id: "",
        date: "",
        currency_code: ""
      }
    })

    assert render(view) =~ "can&#39;t be blank"
  end

  test "creates a new expense with expense items", %{conn: conn, george: george} do
    meks = Users.get_user!(2)
    {:ok, view, _html} = live(conn, ~p"/users/#{george}/expenses/new")

    view
    |> element("form")
    |> render_submit(%{
      expense: %{
        amount_dollars: "100.00",
        description: "Test Expense",
        created_by_user_id: george.id,
        date: "2023-10-01",
        currency_code: "USD",
        expense_items: %{
          "0" => %{
            description: "Item 1",
            amount_dollars: "50.00",
            user_id: george.id
          },
          "1" => %{
            description: "Item 2",
            amount_dollars: "30.00",
            user_id: meks.id
          }
        }
      }
    })

    assert_redirected(view, ~p"/users/#{george}")
  end

  test "displays validation errors for expense items", %{conn: conn, george: george} do
    {:ok, view, _html} = live(conn, ~p"/users/#{george}/expenses/new")

    view
    |> element("form")
    |> render_submit(%{
      expense: %{
        amount_cents: "100.00",
        description: "Test Expense",
        created_by_user_id: george.id,
        date: "2023-10-01",
        currency_code: "",
        expense_items: %{
          "0" => %{
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
