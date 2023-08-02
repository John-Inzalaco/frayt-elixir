defmodule FraytElixir.Shipment.MatchTagsTest do
  use FraytElixir.DataCase
  alias FraytElixir.Shipment.{Match, MatchTags, MatchTag}
  alias FraytElixir.Test.FakeSlack

  describe "create_tag" do
    test "creates a tag" do
      %{id: match_id} = match = insert(:match)
      assert {:ok, %MatchTag{name: :new, match_id: ^match_id}} = MatchTags.create_tag(match, :new)
    end
  end

  describe "set_new_match_tag" do
    test "adds tag to Match and sends message" do
      match = insert(:accepted_match, shipper: insert(:shipper, sales_rep: insert(:admin_user)))
      FakeSlack.clear_messages()

      assert {:ok, %Match{tags: [%MatchTag{name: :new}]}} = MatchTags.set_new_match_tag(match)

      assert [{"#test-shippers", message}] = FakeSlack.get_messages("#test-shippers")

      assert message =~ "has placed their first Match"
    end

    test "adds no tag or slack message without a shipper" do
      match = insert(:accepted_match, shipper: nil)
      FakeSlack.clear_messages()

      assert {:ok, %Match{tags: []}} = MatchTags.set_new_match_tag(match)

      assert [] = FakeSlack.get_messages("#test-shippers")
    end
  end
end
