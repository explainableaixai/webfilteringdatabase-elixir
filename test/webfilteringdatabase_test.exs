defmodule WebFilteringDatabaseTest do
  use ExUnit.Case

  test "constructs a client" do
    client = WebFilteringDatabase.Client.new("test")
    assert client.api_key == "test"
  end
end
