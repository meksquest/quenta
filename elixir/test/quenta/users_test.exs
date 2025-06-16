defmodule Quenta.UsersTest do
  use Quenta.DataCase, async: true
  alias Quenta.Users

  test "list_users/0 returns all users" do
    assert [george, meks] = Users.list_users()
    assert george.name == "George"
    assert meks.name == "Meks"
  end

  test "get_user!/1 returns the user with given id" do
    george = Users.get_user!(1)
    assert george.name == "George"

    meks = Users.get_user!(2)
    assert meks.name == "Meks"
  end

  test "get_user!/1 raises if user does not exist" do
    assert_raise Ecto.NoResultsError, fn ->
      Users.get_user!(999)
    end
  end
end
