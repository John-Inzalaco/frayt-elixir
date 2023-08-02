defmodule FraytElixir.Shipment.MatchWorkflowTest do
  use FraytElixir.DataCase
  use Bamboo.Test

  alias FraytElixir.Shipment
  alias FraytElixir.SLAs.MatchSLA

  alias Shipment.{
    MatchWorkflow,
    Match,
    MatchStateTransition,
    NotEnrouteToDropoffNotifier,
    MatchStop
  }

  alias FraytElixir.Accounts.{ApiAccount, Company, Location}
  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Notifications.SentNotification

  alias FraytElixir.Repo

  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Webhooks.WebhookSupervisor

  import FraytElixir.Factory

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup :start_match_supervisor

  setup do
    FakeSlack.clear_messages()
    start_match_webhook_sender(self())
  end

  describe "activate_match" do
    test "creates FRAYT acceptance, pickup and delivery SLAs" do
      match = insert(:pending_match, state: :pending)

      assert {:ok, %Match{state_transitions: transitions, state: :assigning_driver}} =
               MatchWorkflow.activate_match(match)

      acceptance_start_time =
        transitions
        |> Enum.find(&(&1.to == :assigning_driver))
        |> Map.get(:inserted_at)
        |> DateTime.from_naive!("Etc/UTC")

      assert %Match{slas: slas} =
               Repo.get!(Match, match.id)
               |> Repo.preload(:slas)

      assert [
               %MatchSLA{type: :acceptance, start_time: ^acceptance_start_time, driver_id: nil},
               %MatchSLA{type: :delivery, driver_id: nil},
               %MatchSLA{type: :pickup, driver_id: nil}
             ] = slas |> Enum.sort_by(& &1.type)
    end

    test "scheduled tomorrow" do
      tomorrow = DateTime.utc_now() |> DateTime.add(28 * 3600)
      match = insert(:pending_match, scheduled: true, pickup_at: tomorrow)
      MatchWorkflow.activate_match(match)
      saved_match = Repo.get!(Match, match.id)
      assert saved_match.state == :scheduled
    end

    test "unscheduled match" do
      match = insert(:pending_match, scheduled: false)
      MatchWorkflow.activate_match(match)
      saved_match = Repo.get!(Match, match.id)
      assert saved_match.state == :assigning_driver
    end

    test "scheduled in 30 minutes" do
      soonish = DateTime.utc_now() |> DateTime.add(60 * 60) |> DateTime.truncate(:second)
      end_time = soonish |> DateTime.add(-50 * 60)
      match = insert(:pending_match, scheduled: true, pickup_at: soonish)
      MatchWorkflow.activate_match(match)
      saved_match = Repo.get!(Match, match.id)

      assert saved_match.state == :assigning_driver
      assert %Match{slas: slas} = Repo.get!(Match, match.id) |> Repo.preload(:slas)

      assert [
               %MatchSLA{type: :acceptance, end_time: ^end_time, driver_id: nil}
               | _
             ] = Enum.sort_by(slas, & &1.type)
    end
  end

  test "activate_upcoming_scheduled_matches activates matches scheduled in < 18 hours" do
    tomorrow = DateTime.utc_now() |> DateTime.add(28 * 3600)
    in_1_hour = DateTime.utc_now() |> DateTime.add(1 * 3600)
    tomorrow_match = insert(:match, scheduled: true, pickup_at: tomorrow, state: "scheduled")
    in_1_hour_match = insert(:match, scheduled: true, pickup_at: in_1_hour, state: "scheduled")

    assert {:ok, 1} = MatchWorkflow.activate_upcoming_scheduled_matches()

    tomorrow_match = Repo.get!(Match, tomorrow_match.id)
    in_1_hour_match = Repo.get!(Match, in_1_hour_match.id)

    assert in_1_hour_match.state == :assigning_driver
    assert tomorrow_match.state == :scheduled
  end

  test "activate_upcoming_scheduled_matches activates box truck matches scheduled in < 48 hours" do
    in_3_days = DateTime.utc_now() |> DateTime.add(3 * 24 * 3600)
    tomorrow = DateTime.utc_now() |> DateTime.add(24 * 3600)

    in_3_days_match =
      insert(:match,
        vehicle_class: Shipment.vehicle_class(:box_truck),
        scheduled: true,
        pickup_at: in_3_days,
        state: "scheduled"
      )

    tomorrow_match =
      insert(:match,
        vehicle_class: Shipment.vehicle_class(:box_truck),
        scheduled: true,
        pickup_at: tomorrow,
        state: "scheduled"
      )

    assert {:ok, 1} = MatchWorkflow.activate_upcoming_scheduled_matches()

    in_3_days_match = Repo.get!(Match, in_3_days_match.id)
    tomorrow_match = Repo.get!(Match, tomorrow_match.id)

    assert in_3_days_match.state == :scheduled
    assert tomorrow_match.state == :assigning_driver
  end

  @tag :skip
  test "accepting match stops assigning driver notifications" do
    gaslight_address = build(:address, geo_location: gaslight_point())
    match = insert(:match, origin_address: gaslight_address)
    driver = insert(:driver_with_wallet)

    driver_location_within_5_miles =
      insert(:driver_location, geo_location: findlay_market_point())

    driver_location_within_max_radius =
      insert(:driver_location, geo_location: chris_house_point())

    MatchWorkflow.activate_match(match)

    query =
      from sent in SentNotification,
        where:
          sent.driver_id in [
            ^driver_location_within_5_miles.driver_id,
            ^driver_location_within_max_radius.driver_id
          ]

    :timer.sleep(100)
    sent_notifications = Repo.all(query)
    assert Enum.count(sent_notifications) == 1

    Repo.get!(Match, match.id)
    |> Map.put(:driver_id, driver.id)
    |> Repo.preload([:origin_address, match_stops: :destination_address, shipper: :user])
    |> MatchWorkflow.accept_match()

    :timer.sleep(500)
    sent_notifications = Repo.all(SentNotification)
    assert Enum.count(sent_notifications) == 1
  end

  describe "accept match" do
    setup do
      driver = insert(:driver)
      match = insert(:assigning_driver_match, market: insert(:market), driver: driver)
      FakeSlack.clear_messages()
      %{match: %{match | driver: driver}}
    end

    test "accepts match", %{match: match} do
      MatchWorkflow.accept_match(match)
      saved_match = Repo.get!(Match, match.id) |> Repo.preload(:state_transitions)
      assert saved_match.state == :accepted

      assert [%MatchStateTransition{to: :accepted, inserted_at: inserted_at}] =
               saved_match.state_transitions

      assert DateTime.compare(DateTime.from_naive!(inserted_at, "Etc/UTC"), DateTime.utc_now()) in [
               :lt,
               :eq
             ]
    end

    test "creates acceptance, pickup and delivery SLAs", %{match: match} do
      assert {:ok, %Match{state_transitions: transitions}} = MatchWorkflow.accept_match(match)

      start_time =
        transitions
        |> Enum.find(&(&1.to == :accepted))
        |> Map.get(:inserted_at)
        |> DateTime.from_naive!("Etc/UTC")

      driver_id = match.driver_id

      assert %Match{slas: slas} = Repo.get!(Match, match.id) |> Repo.preload(:slas)

      assert [
               %MatchSLA{type: :acceptance, driver_id: nil},
               %MatchSLA{type: :delivery, driver_id: nil},
               %MatchSLA{type: :delivery, driver_id: ^driver_id},
               %MatchSLA{type: :pickup, driver_id: nil},
               %MatchSLA{type: :pickup, start_time: ^start_time, driver_id: ^driver_id}
             ] = slas |> Enum.sort_by(&{&1.type, &1.driver_id})
    end

    test "accepting match stops unassigned match slack notifications", %{
      match: %Match{driver: driver}
    } do
      match = insert(:match, scheduled: false)
      MatchWorkflow.activate_match(match)
      :timer.sleep(300)
      assert [{_, message1} | _] = FakeSlack.get_messages("#test-dispatch")
      assert String.contains?(message1, "without a driver accepting")
      FakeSlack.clear_messages()
      MatchWorkflow.accept_match(%{match | driver: driver})
      :timer.sleep(150)

      assert [{_, message2} = _match_accepted_message | _] =
               FakeSlack.get_messages("#test-dispatch")

      assert String.contains?(message2, "has been accepted")
      assert String.contains?(message2, match.shortcode)
    end
  end

  describe "force transitions" do
    test "when desired state is same as current state" do
      match = insert(:match, state: "picked_up", state_transitions: [])
      new_match = MatchWorkflow.force_transition_state(match, :picked_up)
      assert new_match.state == match.state
      assert Enum.empty?(new_match.state_transitions)
    end

    test "to picked_up before continuing when in unable to pickup" do
      match = insert(:match, state: :unable_to_pickup, state_transitions: [])
      new_match = MatchWorkflow.force_transition_state(match, :completed)
      assert new_match.state == :completed

      assert [
        %MatchStateTransition{from: :unable_to_pickup, to: :picked_up},
        %MatchStateTransition{from: :picked_up, to: :completed}
      ]
    end

    test "inserts proper state transitions" do
      match = insert(:match, state: "accepted", state_transitions: [])
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)

      assert Enum.empty?(match.state_transitions)
      new_match = MatchWorkflow.force_transition_state(match, :picked_up)
      assert new_match.state == :picked_up
      assert Enum.count(new_match.state_transitions) == 3
    end

    test "inserts proper state transitions in backwards force" do
      match = insert(:completed_match, state_transitions: [])
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)

      assert Enum.empty?(match.state_transitions)
      new_match = MatchWorkflow.force_backwards_transition_state(match, :accepted)
      assert new_match.state == :accepted
      assert Enum.count(new_match.state_transitions) == 1

      match = insert(:completed_match, state_transitions: [])
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver.id)

      assert Enum.empty?(match.state_transitions)
      new_match = MatchWorkflow.force_backwards_transition_state(match, :picked_up)
      assert new_match.state == :picked_up
      assert Enum.count(new_match.state_transitions) == 1
    end

    test "marks pending and in progress match stops as delivered when completed" do
      match =
        insert(:picked_up_match,
          match_stops:
            build_match_stops_with_items([
              :pending,
              :en_route,
              :arrived,
              :signed,
              :delivered,
              :undeliverable
            ])
        )

      %{driver_id: driver_id} = match
      insert(:match_sla, match: match, type: :pickup, driver_id: driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver_id)

      assert %Match{state: :completed, match_stops: stops} =
               MatchWorkflow.force_transition_state(match, :completed)

      assert [
               {:delivered, [:en_route, :arrived, :signed, :delivered]},
               {:delivered, [:arrived, :signed, :delivered]},
               {:delivered, [:signed, :delivered]},
               {:delivered, [:delivered]},
               {:delivered, []},
               {:returned, [:returned]}
             ] =
               Enum.map(
                 stops,
                 fn stop ->
                   {stop.state,
                    Enum.map(
                      stop
                      |> Repo.preload(:state_transitions)
                      |> Map.get(:state_transitions),
                      & &1.to
                    )}
                 end
               )
    end
  end

  describe "arrived_at_pickup" do
    test "arriving at pickup sends push notification" do
      match = insert(:en_route_to_pickup_match)

      MatchWorkflow.arrive_at_pickup(match)

      assert 0 < SentNotification |> Repo.all() |> Enum.count()
    end
  end

  describe "picked_up" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    end

    @tag :skip
    test "marking a match as picked up immediately moves a match stop to en route" do
      match = insert(:arrived_at_pickup_match)

      MatchWorkflow.pickup(match)

      %Match{match_stops: stops} =
        updated_match =
        Repo.get!(Match, match.id) |> Repo.preload([:state_transitions, :match_stops])

      picked_up_transitions =
        updated_match.state_transitions
        |> Enum.filter(&(&1.from == :arrived_at_pickup && &1.to == :picked_up))

      [stop | []] =
        en_route_stops =
        stops
        |> Enum.filter(&(&1.state == :en_route && &1.index == 0))

      assert Enum.count(picked_up_transitions) == 1
      assert Enum.count(en_route_stops) == 1
      assert %{state: :en_route} = stop
    end

    test "picking up triggers webhook with picked_up_time" do
      webhook_url = "https://foo.com"

      %ApiAccount{company: %Company{locations: [%Location{shippers: [shipper | _]} | _]}} =
        insert(:api_account,
          company: build(:company_with_location, webhook_url: "https://foo.com")
        )

      match = insert(:arrived_at_pickup_match, shipper: shipper)
      %{driver_id: driver_id} = match
      insert(:match_sla, match: match, type: :pickup, driver_id: driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver_id)
      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      MatchWorkflow.pickup(match)

      assert_receive {:ok,
                      %HTTPoison.Response{
                        request_url: ^webhook_url,
                        body: %{"picked_up_time" => picked_up_time}
                      }}

      assert {:ok, _date_time, 0} = DateTime.from_iso8601(picked_up_time)
    end

    test "setting state to picked_up from en_route_to_dropoff starts NotEnrouteToDropoffNotifier" do
      %Match{match_stops: [stop]} = match = insert(:en_route_to_dropoff_match)
      stop = %{stop | match: match}

      assert {:ok, _stop} = MatchWorkflow.pending(stop)

      assert match
             |> NotEnrouteToDropoffNotifier.name_for()
             |> GenServer.whereis()
             |> Process.alive?()
    end

    test "setting state back to en_route_to_dropoff from picked_up stops NotEnrouteToDropoffNotifier" do
      # We have to start in :en_route_to_dropoff because the Notifier only starts
      # when you transition from :en_route_to_dropoff to :picked_up
      %Match{match_stops: [stop]} = match = insert(:en_route_to_dropoff_match)
      stop = %{stop | match: match}

      {:ok, stop} = MatchWorkflow.pending(stop)

      stop = %{stop | match: match}

      assert match
             |> NotEnrouteToDropoffNotifier.name_for()
             |> GenServer.whereis()
             |> Process.alive?()

      MatchWorkflow.en_route_to_stop(stop)

      assert nil ==
               match
               |> NotEnrouteToDropoffNotifier.name_for()
               |> GenServer.whereis()
    end
  end

  describe "arrived at dropoff" do
    test "confirming driver is at dropoff transitions to arrived_at_dropoff" do
      %Match{match_stops: [%MatchStop{id: stop_id} = stop]} =
        match = insert(:en_route_to_dropoff_match)

      stop = %{stop | match: match}

      MatchWorkflow.arrive_at_stop(stop)

      assert %{state: :arrived} = Repo.get!(MatchStop, stop_id)
    end
  end

  describe "sign_match_stop" do
    test "transitions to signed" do
      %Match{id: match_id, match_stops: [stop]} = match = insert(:arrived_at_dropoff_match)

      stop = %{stop | match: match}

      assert {:ok, %Match{id: ^match_id, match_stops: [%{state: :signed}]}} =
               MatchWorkflow.sign_for_stop(stop)
    end
  end

  describe "complete_match" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    end

    test "deliver match for signed changes state to completed" do
      match = insert(:match, state: :picked_up)

      assert {:ok, %Match{state: :completed}} = MatchWorkflow.complete_match(match)
    end

    test "delivering match triggers webhook with delivered_time" do
      webhook_url = "https://foo.com"

      %ApiAccount{company: %Company{locations: [%Location{shippers: [shipper | _]} | _]}} =
        insert(:api_account,
          company: build(:company_with_location, webhook_url: "https://foo.com")
        )

      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:delivered_match,
              driver: build(:driver_with_wallet),
              shipper: shipper
            )
        )

      {:ok, pid} = WebhookSupervisor.start_match_webhook_sender(match)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)
      MatchWorkflow.complete_match(match)

      assert_receive {:ok,
                      %HTTPoison.Response{
                        request_url: ^webhook_url,
                        body: %{"delivered_time" => delivered_time}
                      }}

      assert {:ok, _date_time, 0} = DateTime.from_iso8601(delivered_time)
    end

    test "when all stops were masked as undeliverable a new `deadrun` tag is created" do
      match =
        insert(:match,
          state: :picked_up,
          match_stops: [
            build(:match_stop, index: 0, state: :undeliverable),
            build(:match_stop, index: 1, state: :undeliverable),
            build(:match_stop, index: 2, state: :undeliverable)
          ]
        )

      assert {:ok, %Match{state: :completed}} = MatchWorkflow.complete_match(match)

      tags = FraytElixir.Shipment.MatchTags.list_match_tags(match.id)
      assert Enum.any?(tags, fn tag -> tag.name == :deadrun end) == true
    end

    test "updates the pricing of the Match" do
      match =
        insert(:match,
          state: :picked_up,
          fees: [
            build(:match_fee, type: :base_fee, amount: 1000, driver_amount: 750)
          ],
          match_stops: [
            build(:match_stop, index: 0, state: :undeliverable),
            build(:match_stop, index: 1, state: :delivered),
            build(:match_stop, index: 2, state: :delivered)
          ]
        )

      assert {:ok, %Match{state: :completed, fees: fees}} = MatchWorkflow.complete_match(match)

      assert [
               %{type: :base_fee, amount: updated_amount, driver_amount: updated_driver_amount},
               %{type: :route_surcharge}
             ] = Enum.sort_by(fees, & &1.type)

      refute updated_amount == 1000
      refute updated_driver_amount == 750
    end
  end

  describe "driver_cancel_match" do
    setup do
      %{driver_id: driver_id} =
        match =
        insert(
          :accepted_match,
          slas: [
            build(:match_sla),
            build(:match_sla, type: :pickup),
            build(:match_sla, type: :delivery)
          ]
        )

      insert(:match_sla, match: match, type: :pickup, driver_id: driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: driver_id)

      %{match: match}
    end

    test "removes the driver", %{match: match} do
      {:ok, %Match{driver: driver}} = MatchWorkflow.driver_cancel_match(match, "some reason")

      refute(driver)
    end

    test "sets state back to assigning_driver", %{match: match} do
      assert {:ok, %Match{state: :assigning_driver}} =
               MatchWorkflow.driver_cancel_match(match, "some reason")
    end

    test "sets completed_at for driver's SLAs and unset it for FRAYT's ones",
         %{match: match} do
      assert {:ok, %Match{state: :assigning_driver}} =
               MatchWorkflow.driver_cancel_match(match, "some reason")

      %Match{slas: slas} = Repo.get!(Match, match.id) |> Repo.preload(:slas)

      assert Enum.all?(slas, fn sla ->
               case sla do
                 %{driver_id: nil, completed_at: nil} -> true
                 %{driver_id: nil, completed_at: _} -> false
                 %{driver_id: _, completed_at: nil} -> false
                 _ -> true
               end
             end)
    end

    test "sets state to canceled if company has auto_cancel_on_driver_cancel" do
      shipper =
        insert(:shipper_with_location,
          location: build(:location, company: build(:company, auto_cancel_on_driver_cancel: true))
        )

      match = insert(:accepted_match, shipper: shipper)

      insert(:match_state_transition,
        from: :assigning_driver,
        to: :accepted,
        match: match,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 60 * 1000)
      )

      assert {:ok, %Match{state: :canceled}} =
               MatchWorkflow.driver_cancel_match(match, "some reason")
    end
  end

  describe "unable_to_pickup_match" do
    test "Unable to pickup cannot be set either before or after the driver arrived at the pickup" do
      match = insert(:match, state: :arrived_at_pickup)

      {:ok, %Match{state: :unable_to_pickup}} =
        MatchWorkflow.unable_to_pickup_match(match, "some reason")

      match = insert(:accepted_match)
      {:error, :invalid_state} = MatchWorkflow.unable_to_pickup_match(match, "some reason")

      match = insert(:match, state: :picked_up)
      {:error, :invalid_state} = MatchWorkflow.unable_to_pickup_match(match, "some reason")
    end
  end

  describe "admin_renew_match/1" do
    test "sets the match state from :admin_canceled to :accepted" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      driver =
        insert(:driver_with_wallet,
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      %{id: match_id} =
        match =
        insert(:admin_canceled_match,
          driver: driver,
          shipper: build(:shipper, location: build(:location, company: company))
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: match,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 60 * 1000)
      )

      {:ok, %Match{state: state, state_transitions: state_transitions}} =
        MatchWorkflow.admin_renew_match(match)

      assert state == :accepted

      assert Enum.find(state_transitions, &(&1.to == :accepted))

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match_id,
                          "state" => "accepted"
                        }
                      }}
    end

    test "sets the state to :picked_up instead of completed" do
      company =
        insert(:company,
          webhook_url: "http://foo.com",
          webhook_config: %{auth_header: "Authorization", auth_token: "12345"}
        )

      driver =
        insert(:driver_with_wallet,
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      %{id: match_id} =
        match =
        insert(:admin_canceled_match,
          driver: driver,
          shipper: build(:shipper, location: build(:location, company: company)),
          slas: [
            build(:match_sla, type: :acceptance, driver_id: nil),
            build(:match_sla, type: :pickup, driver_id: driver.id),
            build(:match_sla, type: :pickup, driver_id: nil)
          ]
        )

      insert(:match_state_transition,
        from: :completed,
        to: :admin_canceled,
        match: match,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 60 * 1000)
      )

      {:ok, %Match{state: state, state_transitions: state_transitions}} =
        MatchWorkflow.admin_renew_match(match)

      assert state == :picked_up

      assert Enum.find(state_transitions, &(&1.to == :picked_up))

      assert_receive {:ok,
                      %HTTPoison.Response{
                        body: %{
                          "id" => ^match_id,
                          "state" => "picked_up"
                        }
                      }}
    end
  end

  describe "admin_cancel_match/2" do
    test "sets the match state to :admin_canceled with corresponding transition" do
      match = insert(:accepted_match, state_transitions: [])

      {:ok, %Match{state: state, state_transitions: state_transitions}} =
        MatchWorkflow.admin_cancel_match(match)

      assert state == :admin_canceled

      assert Enum.find(state_transitions, &(&1.to == :admin_canceled))
    end

    test "sets the match state to :admin_canceled and sets cancel_reason" do
      match = insert(:accepted_match, state_transitions: [])

      {:ok, %Match{state: state, state_transitions: [last_state_transition | _]}} =
        MatchWorkflow.admin_cancel_match(match, "some random reason")

      assert state == :admin_canceled

      assert %{
               to: :admin_canceled,
               notes: "some random reason"
             } = last_state_transition
    end

    test "sends a slack message" do
      match = insert(:accepted_match)
      FakeSlack.clear_messages()

      assert {:ok, %Match{}} = MatchWorkflow.admin_cancel_match(match)

      assert [{"#test-dispatch", _}] = FakeSlack.get_messages("#test-dispatch")
    end

    test "fails when charged" do
      match = insert(:charged_match)
      FakeSlack.clear_messages()

      assert {:error, :invalid_state} = MatchWorkflow.admin_cancel_match(match)
    end
  end

  describe "shipper_cancel_match/2" do
    test "sets the match state to :canceled with corresponding transition" do
      match = insert(:accepted_match, state_transitions: [])

      {:ok, %Match{state: state, state_transitions: state_transitions}} =
        MatchWorkflow.shipper_cancel_match(match)

      assert state == :canceled

      assert Enum.find(state_transitions, &(&1.to == :canceled))
    end
  end

  describe "all_stops_completed?" do
    test "/1 returns true when all stops are delivered" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "delivered"),
            build(:match_stop, index: 1, state: "delivered"),
            build(:match_stop, index: 2, state: "delivered")
          ]
        )

      assert MatchWorkflow.all_stops_completed?(match_stops) == true
    end

    test "/1 returns false when some stops are delivered" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "delivered"),
            build(:match_stop, index: 1, state: "delivered"),
            build(:match_stop, index: 2, state: "pending")
          ]
        )

      assert MatchWorkflow.all_stops_completed?(match_stops) == false
    end

    test "/1 returns false when no stops are delivered" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "pending"),
            build(:match_stop, index: 1, state: "pending"),
            build(:match_stop, index: 2, state: "pending")
          ]
        )

      assert MatchWorkflow.all_stops_completed?(match_stops) == false
    end

    test "/1 returns true when all stops are delivered or undeliverable" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "delivered"),
            build(:match_stop, index: 1, state: "delivered"),
            build(:match_stop, index: 2, state: "undeliverable"),
            build(:match_stop, index: 3, state: "undeliverable")
          ]
        )

      assert MatchWorkflow.all_stops_completed?(match_stops) == true
    end
  end

  describe "all_stops_undeliverable?" do
    test "/1 returns true when all stops are undeliverable" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "undeliverable"),
            build(:match_stop, index: 1, state: "undeliverable"),
            build(:match_stop, index: 2, state: "undeliverable")
          ]
        )

      assert MatchWorkflow.all_stops_undeliverable?(match_stops) == true
    end

    test "/1 returns false when some stops are undeliverable" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "pending"),
            build(:match_stop, index: 1, state: "en_route"),
            build(:match_stop, index: 2, state: "undeliverable")
          ]
        )

      assert MatchWorkflow.all_stops_undeliverable?(match_stops) == false
    end

    test "/1 returns false when no stops are undeliverable" do
      %{match_stops: match_stops} =
        insert(:match,
          match_stops: [
            build(:match_stop, index: 0, state: "delivered"),
            build(:match_stop, index: 1, state: "delivered"),
            build(:match_stop, index: 2, state: "pending")
          ]
        )

      assert MatchWorkflow.all_stops_undeliverable?(match_stops) == false
    end
  end
end
