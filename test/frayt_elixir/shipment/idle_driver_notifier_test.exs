defmodule FraytElixir.Test.IdleDriverNotifierTest do
  use FraytElixir.DataCase, async: false
  alias FraytElixir.{Repo, Matches}
  alias FraytElixir.Shipment.{Match, MatchWorkflow, IdleDriverNotifier}
  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Test.FakeSlack

  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor

  @admin_alert_message "Driver has accepted a Match that needs to be picked up in 30 minutes"
  @admin_warning_message "Driver has been warned of removal"

  setup do
    {:ok, pid} = start_supervised(IdleDriverNotifier)
    FakeSlack.clear_messages()

    driver = insert(:driver_with_wallet)
    driver = set_driver_default_device(driver)

    %{pid: pid, driver: driver}
  end

  setup :start_match_supervisor

  @tag :skip
  describe "Unscheduled Match Idle Driver Notifier" do
    test "En Route to Pickup removes a driver from the subscribed list", %{pid: pid} do
      match = insert(:assigning_driver_match)

      MatchWorkflow.accept_match(match)
      %{subscribed_matches: matches} = GenServer.call(pid, :get_state)

      assert Enum.count(matches) == 1

      MatchWorkflow.force_transition(match, :en_route_to_pickup)

      :timer.sleep(100)

      %{subscribed_matches: matches} = GenServer.call(pid, :get_state)

      assert Enum.empty?(matches)
    end

    test "Match is added to state when match is accepted", %{
      pid: pid
    } do
      match = insert(:assigning_driver_match, driver: insert(:driver))

      GenServer.call(pid, {:set_stop_flag, :warn_driver})

      MatchWorkflow.accept_match(match)

      :timer.sleep(100)

      %{subscribed_matches: matches} = GenServer.call(pid, :get_state)

      assert matches
             |> Enum.count() == 1
    end

    test "Match is removed from state after cancelled", %{
      pid: pid
    } do
      driver = insert(:driver_with_wallet)
      driver = set_driver_default_device(driver)

      %Match{id: match_id, driver_id: driver_id} =
        match =
        insert(:assigning_driver_match, %{
          driver: driver
        })

      MatchWorkflow.accept_match(match)
      :timer.sleep(250)

      %{subscribed_matches: matches} = GenServer.call(pid, :get_state)

      assert matches
             |> Enum.filter(fn {key, matches} ->
               key == driver_id && Enum.member?(matches, %{match_id: match_id})
             end)
             |> Enum.count() == 0
    end

    test "Warning notification pushed to driver after 15 idle minutes", %{
      pid: pid,
      driver: _driver
    } do
      # "You accepted Match '12345678' 15 minutes ago, but are not en route. Please head towards the pickup address to avoid this match being re-assigned."
      driver = insert(:driver_with_wallet) |> set_driver_default_device()
      match = insert(:accepted_match, driver: driver)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:warn_driver, %Match{}}}, 1200

      :timer.sleep(200)

      [%SentNotification{device_id: _device_id}] = Repo.all(SentNotification)
    end

    test "Admin is notified of an idle driver warning", %{pid: pid, driver: _driver} do
      # "Level: warning. 'Driver has been warned of removal if not en route shortly.'"
      # GenServer.call(pid, {:set_stop_flag, :cancel_driver})

      match = insert(:accepted_match)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:warn_driver, %Match{}}}, 1200

      :timer.sleep(200)

      result =
        FakeSlack.get_messages("#test-high-priority-dispatch")
        |> Enum.find(fn {_k, msg} -> msg =~ @admin_warning_message end)
        |> elem(1)

      assert result =~ @admin_warning_message
    end

    test "Cancel Notification pushed to driver after 20 idle minutes", %{
      pid: pid,
      driver: _driver
    } do
      # "You have been removed from Match #12345678 due to inactivity"
      driver = insert(:driver_with_wallet) |> set_driver_default_device()
      match = insert(:accepted_match, driver: driver)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:cancel_match, %Match{}}}, 2200

      :timer.sleep(200)

      [%SentNotification{device_id: _device_id} | _tail] =
        sent_notifications = Repo.all(SentNotification)

      assert Enum.count(sent_notifications) == 1
    end

    # test "Admin is notified of a driver cancelled", %{pid: pid, driver: _driver} do
    #   match = insert(:accepted_match)

    #   :erlang.trace(pid, true, [:receive])

    #   Kernel.send(pid, {match, :assigning_driver})

    #   assert_receive {:trace, pid, :receive, {:cancel_match, %Match{} = match}}, 2200

    #   :timer.sleep(200)

    #   assert FakeSlack.get_messages()
    #          |> Enum.count(fn {_k, msg} -> msg =~ @admin_cancel_message end) ==
    #            1
    # end

    # test "Cancelled Matches get a 5% bonus to drivers cut and put back into assigning driver", %{
    #   pid: pid
    # } do
    #   %Match{id: id} = match = insert(:accepted_match)

    #   :erlang.trace(pid, true, [:receive])

    #   Kernel.send(pid, {match, :assigning_driver})

    #   assert_receive {:trace, pid, :receive, {:cancel_match, %Match{} = match}}, 2200

    #   :timer.sleep(200)

    #   assert %Match{driver_cut: 0.8, state: :assigning_driver} = Shipment.get_match!(id)
    # end
  end

  @tag :skip
  describe "Scheduled Match Idle Driver Notifier" do
    test "30 minutes prior to scheduled pickup, driver receives a notification", %{
      pid: pid
    } do
      match = insert(:scheduled_accepted_match)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:scheduled_pickup_alert, %Match{}}}, 1750

      :timer.sleep(200)

      [%SentNotification{device_id: _device_id} | _tail] =
        sent_notifications = Repo.all(SentNotification)

      assert Enum.count(sent_notifications) == 1
    end

    test "30 minutes prior to scheduled pickup, admin receives message about scheduled match", %{
      pid: pid
    } do
      match = insert(:scheduled_accepted_match)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:scheduled_pickup_alert, %Match{}}}, 1750

      :timer.sleep(200)

      assert FakeSlack.get_messages("#test-dispatch")
             |> Enum.count(fn {_k, msg} ->
               msg =~ @admin_alert_message
             end) ==
               1
    end

    test "Warning notification pushed to driver after 15 idle minutes", %{
      pid: pid
    } do
      driver = insert(:driver_with_wallet) |> set_driver_default_device()
      match = insert(:scheduled_accepted_match, driver: driver)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:warn_driver, %Match{}}}, 2750

      :timer.sleep(200)

      [%SentNotification{device_id: _device_id} | _] =
        sent_notifications = Repo.all(SentNotification)

      assert Enum.count(sent_notifications) == 2
    end

    test "Admin is notified of an idle driver warning", %{pid: pid} do
      # "Level: warning. 'Driver has been warned of removal if not en route shortly.'"
      match = insert(:scheduled_accepted_match)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:warn_driver, %Match{}}}, 2750

      :timer.sleep(200)

      assert FakeSlack.get_messages()
             |> Enum.count(fn {_k, msg} -> msg =~ @admin_warning_message end) == 1
    end

    test "Cancel Notification pushed to driver after 20 idle minutes", %{pid: pid} do
      # "You have been removed from Match #12345678 due to inactivity"
      driver = insert(:driver_with_wallet) |> set_driver_default_device()
      match = insert(:scheduled_accepted_match, driver: driver)

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:cancel_match, %Match{}}}, 3750

      :timer.sleep(200)

      [%SentNotification{device_id: _device_id} | _tail] =
        sent_notifications = Repo.all(SentNotification)

      assert Enum.count(sent_notifications) == 2
    end

    # test "Admin is notified of a driver cancelled", %{pid: pid} do
    #   match = insert(:scheduled_accepted_match)

    #   :erlang.trace(pid, true, [:receive])

    #   Kernel.send(pid, {match, :assigning_driver})

    #   assert_receive {:trace, pid, :receive, {:cancel_match, %Match{} = match}}, 3750

    #   :timer.sleep(200)

    #   assert FakeSlack.get_messages()
    #          |> Enum.count(fn {_k, msg} -> msg =~ @admin_cancel_message end) ==
    #            1
    # end

    # test "driver cut is increased by 5%, and match is set to assigning driver cancelled matches",
    #      %{pid: pid} do
    #   %Match{id: id} = match = insert(:scheduled_accepted_match)

    #   :erlang.trace(pid, true, [:receive])

    #   Kernel.send(pid, {match, :assigning_driver})

    #   assert_receive {:trace, pid, :receive, {:cancel_match, %Match{} = match}}, 3750

    #   :timer.sleep(200)

    #   assert %Match{
    #            driver_cut: 0.8,
    #            driver_base_price: updated_base_price,
    #            state: :assigning_driver
    #          } = Shipment.get_match!(id)
    # end

    test "Notification always sends at 30 minutes prior to pickup, even if Admin changes pickup time",
         %{pid: pid} do
      now = DateTime.utc_now()
      pickup = now |> DateTime.add(6000, :millisecond)
      updated_pickup = now |> DateTime.add(4000, :millisecond)

      %Match{id: id} =
        match =
        insert(:scheduled_accepted_match, %{
          pickup_at: pickup
        })

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      :timer.sleep(200)

      {:ok, _updated_match} =
        Matches.update_match(match, %{
          pickup_at: updated_pickup
        })

      assert_receive {:trace, ^pid, :receive, {:scheduled_pickup_alert, %Match{id: ^id}}},
                     4000

      :timer.sleep(200)

      assert FakeSlack.get_messages("#test-dispatch")
             |> Enum.count(fn {_k, msg} ->
               msg =~ @admin_alert_message
             end) ==
               1
    end

    test "Driver inside 30min pickup windows gets notifications", %{pid: pid} do
      # After acceptance, set timer for 30sec and mark enroute warning after that
      # If within 15 min window, dont cancel driver"
      # Admin Note: "Driver accepted within 15min of pickup window he will not be automatically removed if running late."

      match =
        insert(:scheduled_accepted_match, %{
          pickup_at: DateTime.utc_now() |> DateTime.add(100, :millisecond)
        })

      :erlang.trace(pid, true, [:receive])

      Kernel.send(pid, {match, :assigning_driver})

      assert_receive {:trace, ^pid, :receive, {:warn_driver, %Match{}}}, 1200

      :timer.sleep(200)

      assert FakeSlack.get_messages("#test-high-priority-dispatch")
             |> Enum.count(fn {_k, msg} ->
               msg =~ @admin_warning_message
             end) ==
               1
    end

    test "Short Notice tests to see if the pickup time is within a 30min window of now" do
      now = DateTime.utc_now()

      refute now
             |> DateTime.add(3000, :millisecond)
             |> IdleDriverNotifier.short_notice?()

      assert now
             |> DateTime.add(50, :millisecond)
             |> IdleDriverNotifier.short_notice?()
    end
  end
end
