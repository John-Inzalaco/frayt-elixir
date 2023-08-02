defmodule FraytElixir.Test.NotPickedUpNotifierTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.NotPickedUpNotifier
  alias FraytElixir.Test.FakeSlack

  import FraytElixir.Factory

  describe "not picked up notifier" do
    setup do
      FakeSlack.clear_messages()
    end

    test "Send notification if scheduled match is in :accepted/:en_route_to_pickup state for too long" do
      pickup = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 1000, :millisecond)
      dropoff = pickup |> DateTime.add(2000, :millisecond)

      match =
        insert(:accepted_match,
          state: "accepted",
          pickup_at: pickup,
          dropoff_at: dropoff,
          scheduled: true
        )

      notification_threshold = 100
      max_notifcation_time = 4000

      NotPickedUpNotifier.new(
        match,
        600,
        notification_threshold,
        max_notifcation_time
      )

      :timer.sleep(300)

      assert [{_, sent_message1} | _] = FakeSlack.get_messages("#test-dispatch")
      assert String.contains?(sent_message1, match.shortcode)
      assert String.contains?(sent_message1, "minutes after scheduled pickup")
    end

    test "Send notification if unscheduled match is in :accepted/:en_route_to_pickup state for too long" do
      match = insert(:accepted_match)

      unscheduled_delay = 0
      notification_threshold = 100
      max_notifcation_time = 4000

      NotPickedUpNotifier.new(
        match,
        unscheduled_delay,
        notification_threshold,
        max_notifcation_time
      )

      :timer.sleep(300)

      assert [{_, sent_message1} | _] = FakeSlack.get_messages("#test-dispatch")

      assert String.contains?(sent_message1, match.shortcode)
      assert String.contains?(sent_message1, "minutes ago and has not picked up")
    end
  end
end
