defmodule FraytElixir.Shipment.DeliveryBatchRouterTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.{
    DeliveryBatch,
    DeliveryBatchRouter,
    DeliveryBatchSupervisor,
    Match,
    MatchStop,
    DeliveryBatches,
    BatchStateTransition
  }

  alias FraytElixir.Repo

  alias FraytElixir.Accounts.Schedule
  alias Phoenix.PubSub
  alias FraytElixir.Test.FakeRoutific
  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup :start_match_supervisor

  setup do
    {:ok, _spid} = start_supervised({Task.Supervisor, name: DeliveryBatchSupervisor})
    start_match_webhook_sender(self())
    :ok
  end

  describe "route_batch" do
    test "calls routific" do
      %Schedule{location: location, drivers: drivers} = insert(:schedule_with_drivers)

      %DeliveryBatch{match_stops: match_stops} =
        delivery_batch =
        insert(:delivery_batch, location: location, match_stops: build_list(25, :match_stop))

      assert {:ok, _batch, job_id} = DeliveryBatchRouter.route_batch(delivery_batch)

      assert %{request: %{"fleet" => fleet, "visits" => visits}} = FakeRoutific.get_job(job_id)

      assert drivers |> Enum.map(& &1.id) |> Enum.sort() == fleet |> Map.keys() |> Enum.sort()

      assert fleet
             |> Enum.all?(fn {_, %{"start_location" => %{"lat" => lat, "lng" => lng}}} ->
               lat && lng
             end)

      assert Enum.count(visits) == 25

      assert match_stops |> Enum.map(& &1.id) |> Enum.sort() ==
               visits |> Map.keys() |> Enum.sort()

      assert visits
             |> Enum.all?(fn {_, %{"location" => %{"lat" => lat, "lng" => lng}}} -> lat && lng end)
    end

    test "calls routific when location address isn't geocoded" do
      %Schedule{location: location, drivers: drivers} =
        insert(:schedule_with_drivers,
          location:
            build(:location, address: build(:address, geo_location: nil, formatted_address: nil))
        )

      %DeliveryBatch{match_stops: match_stops} =
        delivery_batch =
        insert(:delivery_batch, location: location, match_stops: build_list(25, :match_stop))

      assert {:ok, _batch, job_id} = DeliveryBatchRouter.route_batch(delivery_batch)
      assert %{request: %{"fleet" => fleet, "visits" => visits}} = FakeRoutific.get_job(job_id)
      assert drivers |> Enum.map(& &1.id) |> Enum.sort() == fleet |> Map.keys() |> Enum.sort()

      assert fleet
             |> Enum.all?(fn {_, %{"start_location" => %{"lat" => lat, "lng" => lng}}} ->
               lat && lng
             end)

      assert Enum.count(visits) == 25

      assert match_stops |> Enum.map(& &1.id) |> Enum.sort() ==
               visits |> Map.keys() |> Enum.sort()

      assert visits
             |> Enum.all?(fn {_, %{"location" => %{"lat" => lat, "lng" => lng}}} -> lat && lng end)
    end

    test "calls routific with no schedule" do
      %DeliveryBatch{match_stops: match_stops} =
        delivery_batch =
        insert(:delivery_batch, location: nil, match_stops: build_list(25, :match_stop))

      assert {:ok, _batch, job_id} = DeliveryBatchRouter.route_batch(delivery_batch)

      assert %{request: %{"fleet" => fleet, "visits" => visits}} = FakeRoutific.get_job(job_id)

      assert fleet |> Map.keys() |> length() > 0

      assert fleet
             |> Enum.all?(fn {_, %{"start_location" => %{"lat" => lat, "lng" => lng}}} ->
               lat && lng
             end)

      assert Enum.count(visits) == 25

      assert match_stops |> Enum.map(& &1.id) |> Enum.sort() ==
               visits |> Map.keys() |> Enum.sort()

      assert visits
             |> Enum.all?(fn {_, %{"location" => %{"lat" => lat, "lng" => lng}}} -> lat && lng end)
    end
  end

  describe "new/1" do
    test "routes batch and creates matches" do
      delivery_batch =
        insert(:delivery_batch,
          location: nil,
          match_stops: build_list(3, :match_stop),
          shipper: build(:shipper, location: build(:location))
        )

      :ok = PubSub.subscribe(FraytElixir.PubSub, "batch_state_transitions:#{delivery_batch.id}")

      assert {:ok, pid} = DeliveryBatchRouter.new(%{delivery_batch: delivery_batch})

      job_id = GenServer.call(pid, :get_job_id)

      :ok = FakeRoutific.set_status_response(job_id, :finished)

      assert_receive {%DeliveryBatch{state: :routing},
                      %BatchStateTransition{from: :pending, to: :routing}},
                     1000

      assert_receive {%DeliveryBatch{state: :routing_complete},
                      %BatchStateTransition{from: :routing, to: :routing_complete}},
                     6000

      assert %DeliveryBatch{matches: matches} =
               Repo.get(DeliveryBatch, delivery_batch.id) |> Repo.preload(:matches)

      assert length(matches) == 3
    end

    test "handles unserved stop" do
      delivery_batch =
        insert(:delivery_batch,
          location: nil,
          match_stops: build_list(4, :match_stop),
          shipper: build(:shipper, location: build(:location))
        )

      :ok = PubSub.subscribe(FraytElixir.PubSub, "batch_state_transitions:#{delivery_batch.id}")

      assert {:ok, pid} = DeliveryBatchRouter.new(%{delivery_batch: delivery_batch})

      job_id = GenServer.call(pid, :get_job_id)

      :ok = FakeRoutific.set_status_response(job_id, :unserved)

      assert_receive {%DeliveryBatch{state: :routing},
                      %BatchStateTransition{from: :pending, to: :routing}},
                     1000

      assert_receive {%DeliveryBatch{state: :routing_complete},
                      %BatchStateTransition{from: :routing, to: :routing_complete}},
                     6000

      assert %DeliveryBatch{match_stops: stops} =
               Repo.get(DeliveryBatch, delivery_batch.id) |> Repo.preload(:match_stops)

      assert [%{state: :unserved}] = stops |> Enum.filter(&(&1.state == :unserved))
    end

    test "handles routific error" do
      delivery_batch =
        insert(:delivery_batch, location: nil, match_stops: build_list(4, :match_stop))

      :ok = PubSub.subscribe(FraytElixir.PubSub, "batch_state_transitions:#{delivery_batch.id}")

      assert {:ok, pid} = DeliveryBatchRouter.new(%{delivery_batch: delivery_batch})

      job_id = GenServer.call(pid, :get_job_id)

      :ok = FakeRoutific.set_status_response(job_id, :error)

      assert_receive {%DeliveryBatch{state: :routing},
                      %BatchStateTransition{from: :pending, to: :routing}},
                     1000

      assert_receive {%DeliveryBatch{state: :error},
                      %BatchStateTransition{
                        from: :routing,
                        to: :error,
                        notes:
                          "Sorry - we couldn't find a route for you today. Can you check your driver/stop inputs?"
                      }},
                     1000
    end

    test "handles create_match error" do
      delivery_batch =
        insert(:delivery_batch,
          pickup_at: ~N[2030-12-25 00:00:00],
          location: nil,
          match_stops: build_list(4, :match_stop),
          shipper: build(:shipper, location: build(:location))
        )

      :ok = PubSub.subscribe(FraytElixir.PubSub, "batch_state_transitions:#{delivery_batch.id}")

      assert {:ok, pid} = DeliveryBatchRouter.new(%{delivery_batch: delivery_batch})

      job_id = GenServer.call(pid, :get_job_id)

      :ok = FakeRoutific.set_status_response(job_id, :finished)

      assert_receive {%DeliveryBatch{state: :routing},
                      %BatchStateTransition{from: :pending, to: :routing}},
                     1000
    end
  end

  describe "create_matches" do
    test "create_matches creates multistop matches from routific solution" do
      %Schedule{location: location, drivers: [driver1, driver2]} = insert(:schedule_with_drivers)

      %DeliveryBatch{match_stops: [match_stop1, match_stop2, match_stop3, match_stop4]} =
        delivery_batch =
        insert(:delivery_batch,
          location: location,
          match_stops: build_list(4, :match_stop, match: nil),
          shipper: build(:shipper, location: location)
        )

      routific_output = %{
        "solution" => %{
          driver1.id => [
            %{"location_id" => "#{driver1.id}_start"},
            %{"location_id" => match_stop4.id},
            %{"location_id" => match_stop1.id}
          ],
          driver2.id => [
            %{"location_id" => "#{driver2.id}_start"},
            %{"location_id" => match_stop3.id},
            %{"location_id" => match_stop2.id}
          ]
        }
      }

      assert {:ok, %{update_batch: delivery_batch}} =
               DeliveryBatchRouter.create_matches(delivery_batch, routific_output)

      assert %{matches: [match1 | _] = matches} =
               DeliveryBatches.get_delivery_batch(delivery_batch.id)

      assert matches |> Enum.count() == 2

      match1 =
        match1
        |> Repo.preload([{:match_stops, from(ms in MatchStop, order_by: ms.index)}])

      assert match1.shortcode
      assert match1.amount_charged
      assert match1.total_distance
      assert match1.service_level == 1
      assert match1.pickup_at == delivery_batch.pickup_at
      assert match1.scheduled
      assert match1.state == :scheduled
    end

    test "create_matches when no location" do
      card = insert(:credit_card, shipper: build(:shipper, location: build(:location)))

      %DeliveryBatch{
        address_id: address_id,
        shipper_id: shipper_id,
        match_stops: [match_stop1, match_stop2, match_stop3, match_stop4]
      } =
        delivery_batch =
        insert(:delivery_batch,
          shipper: card.shipper,
          match_stops: build_list(4, :match_stop, match: nil),
          contract: nil,
          po: "1234",
          pickup_notes: "notes"
        )

      routific_output = %{
        "solution" => %{
          "3_d1" => [
            %{"location_id" => "3_d1_start"},
            %{"location_id" => match_stop4.id},
            %{"location_id" => match_stop1.id},
            %{"location_id" => match_stop3.id},
            %{"location_id" => match_stop2.id}
          ]
        }
      }

      assert {:ok, %{update_batch: delivery_batch}} =
               DeliveryBatchRouter.create_matches(delivery_batch, routific_output)

      assert %{
               matches: [match]
             } = DeliveryBatches.get_delivery_batch(delivery_batch.id)

      assert %Match{
               contract_id: nil,
               po: "1234",
               pickup_notes: "notes",
               shipper_id: ^shipper_id,
               state: :scheduled,
               origin_address_id: ^address_id,
               match_stops: [_, _, _, _],
               driver: nil
             } = match |> Repo.preload([:match_stops, :driver])
    end

    test "create_matches when routific does not give all the drivers any locations" do
      %Schedule{location: location, drivers: [driver1, driver2]} = insert(:schedule_with_drivers)

      %DeliveryBatch{match_stops: [match_stop1, match_stop2, match_stop3, match_stop4]} =
        delivery_batch =
        insert(:delivery_batch,
          location: location,
          match_stops: build_list(4, :match_stop, match: nil),
          shipper: build(:shipper, location: location)
        )

      routific_output = %{
        "solution" => %{
          driver1.id => [
            %{"location_id" => "#{driver1.id}_start"},
            %{"location_id" => match_stop4.id},
            %{"location_id" => match_stop1.id},
            %{"location_id" => match_stop3.id},
            %{"location_id" => match_stop2.id}
          ],
          driver2.id => [
            %{"location_id" => "#{driver2.id}_start"}
          ]
        }
      }

      assert {:ok, %{update_batch: delivery_batch}} =
               DeliveryBatchRouter.create_matches(delivery_batch, routific_output)

      assert %{
               matches: [
                 %{
                   state: :scheduled
                 }
               ]
             } = DeliveryBatches.get_delivery_batch(delivery_batch.id)
    end
  end

  test "Build visit converts load from cubic inches to cubic feet" do
    load = 12 * 12 * 12 * 6

    stop = insert(:match_stop, items: [build(:match_stop_item, volume: load, pieces: 1)])

    assert %{load: 6} = DeliveryBatchRouter.build_visit(stop)
  end

  test "Build visits returns the dropoff_by match_stop field to Routific's 'end'" do
    stop = insert(:match_stop, dropoff_by: ~N[2020-10-01 13:31:59])

    assert %{end: "13:31"} = DeliveryBatchRouter.build_visit(stop)

    stop = insert(:match_stop, dropoff_by: ~N[2020-10-01 08:01:59])

    assert %{end: "08:01"} = DeliveryBatchRouter.build_visit(stop)
  end
end
