defmodule HexWeb.API.KeyTest do
  use HexWebTest.Case

  alias HexWeb.User
  alias HexWeb.API.Key

  setup do
    {:ok, _} = User.create("eric", "eric@mail.com", "eric")
    :ok
  end

  test "create key and get" do
    user = User.get(username: "eric")
    user_id = user.id
    assert {:ok, %Key{}} = Key.create("computer", user)
    assert %Key{user_id: ^user_id} = Key.get("computer", user)
  end

  test "create unique key name" do
    user = User.get(username: "eric")
    assert {:ok, %Key{name: "computer"}}   = Key.create("computer", user)
    assert {:ok, %Key{name: "computer-2"}} = Key.create("computer", user)
  end

  test "all user keys" do
    eric = User.get(username: "eric")
    {:ok, jose} = User.create("jose", "jose@mail.com", "jose")
    assert {:ok, %Key{name: "computer"}} = Key.create("computer", eric)
    assert {:ok, %Key{name: "macbook"}}  = Key.create("macbook", eric)
    assert {:ok, %Key{name: "macbook"}}  = Key.create("macbook", jose)

    assert length(Key.all(eric)) == 2
    assert length(Key.all(jose)) == 1
  end

  test "delete keys" do
    user = User.get(username: "eric")
    assert {:ok, %Key{}} = Key.create("computer", user)
    assert {:ok, %Key{}} = Key.create("macbook", user)
    assert Key.delete(Key.get("computer", user)) == :ok

    assert [%Key{name: "macbook"}] = Key.all(user)
  end
end
