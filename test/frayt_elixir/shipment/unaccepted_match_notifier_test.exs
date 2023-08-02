defmodule FraytElixir.Test.UnacceptedMatchNotifierTest do
  use FraytElixir.DataCase
  use Bamboo.Test, shared: true

  alias FraytElixir.Email
  alias FraytElixir.Shipment.{UnacceptedMatchNotifier, Match}
  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Drivers
  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.MatchSupervisor

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Factory

  describe "match supervisor" do
    setup do
      FakeSlack.clear_messages()
    end

    test "uses auto_cancel_time from company config" do
      shipper =
        insert(:shipper_with_location,
          location:
            build(:location, company: build(:company, auto_cancel: true, auto_cancel_time: 100))
        )

      match =
        insert(:assigning_driver_match,
          shipper: shipper
        )

      {:ok, pid} = start_supervised(MatchSupervisor)
      Supervisor.stop(pid)

      :timer.sleep(200)

      FakeSlack.get_messages("#test-dispatch")
      |> Enum.each(fn {_, message} ->
        assert message =~ "Canceled automatically"
      end)

      assert %Match{
               state: :admin_canceled
             } = Repo.get!(Match, match.id)
    end

    test "uses default auto_cancel_time if not set on the company" do
      shipper =
        insert(:shipper_with_location,
          location: build(:location, company: build(:company, auto_cancel: true))
        )

      match =
        insert(:assigning_driver_match,
          shipper: shipper
        )

      {:ok, pid} = start_supervised(MatchSupervisor)
      Supervisor.stop(pid)

      :timer.sleep(1000)

      assert FakeSlack.get_messages("#test-dispatch")
             |> Enum.all?(fn {_, message} ->
               cancelled = message =~ "Canceled automatically"
               !cancelled
             end)

      assert %Match{
               state: :assigning_driver
             } = Repo.get!(Match, match.id)
    end
  end

  describe "unaccepted match notifier" do
    setup :start_match_supervisor

    setup do
      FakeSlack.clear_messages()
    end

    test "matches in assigning_driver trigger notification" do
      match = insert(:match, state: "assigning_driver", service_level: 1)

      UnacceptedMatchNotifier.new(match, 100, 300)
      :timer.sleep(500)
      [{_, sent_message2}, {_, sent_message1} | _] = FakeSlack.get_messages("#test-dispatch")
      assert sent_message1 =~ match.shortcode
      assert sent_message1 =~ "for 0 minutes"
      assert sent_message1 =~ "(dash)"
      assert sent_message2 =~ match.shortcode
      assert sent_message2 =~ "final warning"

      FakeSlack.clear_messages()
      :timer.sleep(100)
      assert [] = FakeSlack.get_messages("#test-dispatch")
    end

    test "scheduled matches do not trigger notifications when more than 30 minutes out" do
      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(40 * 60, :second)
        )

      UnacceptedMatchNotifier.new(match, 100, 300)
      :timer.sleep(600)
      [] = FakeSlack.get_messages("#test-dispatch")
    end

    test "scheduled matches triggers notifications when 30 minutes out" do
      gaslight_address = build(:address, geo_location: gaslight_point())

      match =
        insert(:scheduled_assigning_driver,
          origin_address: gaslight_address,
          pickup_at: DateTime.utc_now() |> DateTime.add(30 * 60, :second)
        )

      %{driver: driver} = insert(:driver_location, geo_location: findlay_market_point())
      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, findlay_market_point())

      UnacceptedMatchNotifier.new(match, 100, 3000)

      :timer.sleep(4000)

      assert SentNotification
             |> Repo.all()
             |> Enum.count() > 0

      messages = FakeSlack.get_messages("#test-dispatch")

      assert messages
             |> Enum.any?(fn {_, warning_message} ->
               warning_message =~ "needs picked up" and
                 not String.contains?(warning_message, "This is the final warning")
             end)

      assert messages
             |> Enum.any?(fn {_, final_message} ->
               final_message =~ "This is the final warning"
             end)

      assert %Match{
               state: :assigning_driver,
               driver_cut: 0.75
             } = Repo.get!(Match, match.id)
    end

    test "cancels a match automatically when auto_cancel is enabled" do
      shipper =
        insert(:shipper_with_location,
          location: build(:location, company: build(:company, auto_cancel: true))
        )

      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(30 * 60, :second),
          shipper: shipper
        )

      UnacceptedMatchNotifier.new(match, 100, 3000)

      :timer.sleep(4000)

      assert FakeSlack.get_messages("#test-dispatch")
             |> Enum.any?(fn {_, message} ->
               message =~ "Canceled automatically"
             end)

      assert %Match{
               state: :admin_canceled
             } = Repo.get!(Match, match.id)
    end

    test "removes preferred driver and notifies shipper for preferred driver matches" do
      %{user: %{email: email_address}} =
        shipper =
        insert(:shipper_with_location,
          location:
            build(:location, company: build(:company, auto_cancel: true, auto_cancel_time: 100))
        )

      driver = insert(:driver)
      set_driver_default_device(driver)

      match =
        insert(:assigning_driver_match,
          platform: :deliver_pro,
          preferred_driver_id: driver.id,
          shipper: shipper
        )

      expected_email =
        Email.match_status_email(
          match,
          [status_type: :preferred_driver_unassigned, driver: driver],
          %{
            to: email_address,
            subject:
              "#{driver.first_name} #{driver.last_name} Unassigned – #{match.po}/#{match.shortcode}",
            html_body: "#{driver.first_name} #{driver.last_name} did not accept the match"
          }
        )

      UnacceptedMatchNotifier.new(match, 100, 200)

      :timer.sleep(500)

      assert %Match{preferred_driver_id: nil} = Repo.get!(Match, match.id)

      assert_delivered_email(expected_email)
    end

    # this feature is temporarily disabled
    @tag :skip
    test "increases driver cut when auto_incentivize_driver is enabled" do
      shipper =
        insert(:shipper_with_location,
          location: build(:location, company: build(:company, auto_incentivize_driver: true))
        )

      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(30 * 60, :second),
          shipper: shipper
        )

      UnacceptedMatchNotifier.new(match, 100, 600)

      :timer.sleep(700)

      assert %Match{
               driver_cut: 0.9
             } = Repo.get!(Match, match.id)
    end

    test "scheduled matches triggers notifications when after pickup time" do
      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(-120, :second)
        )

      UnacceptedMatchNotifier.new(match, 100, 200)

      :timer.sleep(300)

      [{_, final_message}] = FakeSlack.get_messages("#test-dispatch")

      assert final_message =~ "needed picked up 2 minutes ago"
      assert final_message =~ "final warning"
    end

    # next to impossible to test this with dynamic initial config conditions
    test "Dash match created earlier shows proper elapsed time in warning" do
      match = insert(:match, state: "assigning_driver", service_level: 1, scheduled: false)
      hundred_milliseconds_earlier = DateTime.utc_now() |> DateTime.add(-300, :millisecond)

      insert(:match_state_transition,
        from: :pending,
        to: :assigning_driver,
        match: match,
        inserted_at: hundred_milliseconds_earlier
      )

      UnacceptedMatchNotifier.new(match, 100, 1000)
      :timer.sleep(1000)
      [{_, final_message} | _] = FakeSlack.get_messages("#test-dispatch")
      assert final_message =~ match.shortcode
      assert final_message =~ "final warning"

      FakeSlack.clear_messages()
      :timer.sleep(100)
      assert [] = FakeSlack.get_messages("#test-dispatch")
    end

    # next to impossible to test this with dynamic initial config conditions
    test "Scheduled match with recent pickup_at shows proper elapsed time in warning" do
      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(30 * 60, :second)
        )

      UnacceptedMatchNotifier.new(match, 100, 1000)
      :timer.sleep(2000)
      [{_, final_message}, {_, warning_message} | _] = FakeSlack.get_messages("#test-dispatch")
      assert warning_message =~ "needs picked up"
      assert final_message =~ match.shortcode
      assert final_message =~ "final warning"

      FakeSlack.clear_messages()
      :timer.sleep(100)
      assert [] = FakeSlack.get_messages("#test-dispatch")
    end
  end

  describe "get_initial_config/2" do
    test "match with scheduled pickup 40mins away should return a ~10min initial_interval" do
      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(40 * 60, :second)
        )

      assert {initial_interval, elapsed} =
               UnacceptedMatchNotifier.get_initial_config(match, 600_000)

      assert (initial_interval - 10 * 60_000) |> abs() < 10_000
      assert elapsed == 0
    end

    test "match with scheduled pickup 25mins away should return a ~5min initial_interval and ~5min elapsed time" do
      match =
        insert(:scheduled_assigning_driver,
          pickup_at: DateTime.utc_now() |> DateTime.add(25 * 60, :second)
        )

      assert {initial_interval, elapsed} =
               UnacceptedMatchNotifier.get_initial_config(match, 600_000)

      assert (initial_interval - 5 * 60_000) |> abs() < 10_000
      assert (elapsed - 5 * 60_000) |> abs() < 10_000
    end

    test "unscheduled match just activated should return a ~10min initial_interval" do
      match = insert(:match, state: "assigning_driver", service_level: 1, scheduled: false)

      insert(:match_state_transition,
        from: :pending,
        to: :assigning_driver,
        match: match,
        inserted_at: DateTime.utc_now()
      )

      assert {initial_interval, elapsed} =
               UnacceptedMatchNotifier.get_initial_config(match, 600_000)

      assert (initial_interval - 10 * 60_000) |> abs() < 10_000
      assert elapsed < 10_000
    end

    test "unscheduled match activated 15mins ago should return a ~5min initial_interval and ~15min elapsed time" do
      match = insert(:match, state: "assigning_driver", service_level: 1, scheduled: false)

      insert(:match_state_transition,
        from: :pending,
        to: :assigning_driver,
        match: match,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 15 * 60, :second)
      )

      assert {initial_interval, elapsed} =
               UnacceptedMatchNotifier.get_initial_config(match, 600_000)

      assert (initial_interval - 5 * 60_000) |> abs() < 10_000
      assert (elapsed - 15 * 60_000) |> abs() < 10_000
    end
  end
end
