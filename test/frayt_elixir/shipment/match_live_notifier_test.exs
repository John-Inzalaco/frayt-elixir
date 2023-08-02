defmodule FraytElixir.Shipment.MatchLiveNotifierTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.MatchLiveNotifier
  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Matches
  alias FraytElixir.Shipment.{Match, Address, MatchWorkflow}
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup :start_match_supervisor

  setup do
    {:ok, pid} = start_supervised(MatchLiveNotifier)
    FakeSlack.clear_messages()
    start_match_webhook_sender(self())
    %{pid: pid}
  end

  test "new live match sends a slack message" do
    match = insert(:pending_match, shipper: build(:shipper_with_location, state: :approved))

    {:ok, %Match{shortcode: shortcode}} = Matches.update_and_authorize_match(match)

    :timer.sleep(50)

    assert FakeSlack.get_messages("#test-dispatch")
           |> Enum.any?(fn {_channel, message} ->
             String.contains?(message, shortcode) and String.contains?(message, "live")
           end)
  end

  test "new scheduled match sends a slack message" do
    tomorrow = Timex.now("America/New_York") |> Timex.shift(days: 1)

    tomorrow_match =
      insert(:pending_match,
        scheduled: true,
        pickup_at: tomorrow,
        shipper: build(:shipper_with_location, state: :approved),
        origin_address: build(:address, geo_location: chris_house_point())
      )

    assert {:ok, %Match{origin_address: %Address{city: city}, shortcode: shortcode}} =
             Matches.update_and_authorize_match(tomorrow_match)

    # If set to ~100, match not accepted notification will begin going out
    :timer.sleep(50)

    assert [{_, message}] = FakeSlack.get_messages("#test-dispatch")
    assert String.contains?(message, shortcode)
    assert String.contains?(message, city)

    assert String.contains?(message, to_string(tomorrow.day))

    assert String.contains?(message, to_string(tomorrow.year))
    assert String.contains?(message, "scheduled")
  end

  test "scheduled match going live sends a slack message" do
    in_1_hour = DateTime.utc_now() |> DateTime.add(1 * 3600)

    %Match{shortcode: shortcode} =
      insert(:match,
        scheduled: true,
        pickup_at: in_1_hour,
        state: :scheduled,
        origin_address: build(:address)
      )

    assert {:ok, 1} = MatchWorkflow.activate_upcoming_scheduled_matches()

    assert 1 ==
             FakeSlack.get_messages("#test-dispatch")
             |> Enum.filter(fn {_channel, message} ->
               message =~ shortcode && message =~ "live"
             end)
             |> Enum.count()
  end
end
