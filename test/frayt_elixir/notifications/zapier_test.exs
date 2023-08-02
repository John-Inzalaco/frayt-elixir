defmodule FraytElixir.Notifications.ZapierTest do
  use FraytElixir.DataCase
  alias FraytElixir.Notifications.Zapier

  describe "send_match_status/2" do
    test "triggers zapier webhook" do
      match = insert(:match)

      assert {:ok, %HTTPoison.Response{}} = Zapier.send_match_status(match)
    end
  end
end
