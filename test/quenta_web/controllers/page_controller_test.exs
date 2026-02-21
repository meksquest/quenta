defmodule QuentaWeb.PageControllerTest do
  use QuentaWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome to Quenta"
  end
end
