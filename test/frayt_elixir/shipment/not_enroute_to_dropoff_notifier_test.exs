defmodule FraytElixir.Test.NotEnrouteToDropoffNotifierTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.NotEnrouteToDropoffNotifier
  alias FraytElixir.Test.FakeSlack

  import FraytElixir.Factory

  describe "not enroute to dropoff notifier" do
    setup do
      FakeSlack.clear_messages()
    end

    test "Should send notification if match is in :picked_up state for too long" do
      match = insert(:picked_up_match)

      notification_threshold = 100
      max_notifcation_time = 300

      NotEnrouteToDropoffNotifier.new(
        match,
        notification_threshold,
        max_notifcation_time
      )

      :timer.sleep(400)

      assert [{_, sent_message_final}, {_, sent_message_first}] =
               FakeSlack.get_messages("#test-dispatch")

      assert String.contains?(sent_message_first, match.shortcode)
      assert String.contains?(sent_message_first, "is not yet En Route to dropoff")

      assert String.contains?(sent_message_final, match.shortcode)
      assert String.contains?(sent_message_final, "This is the final warning")
    end
  end
end
