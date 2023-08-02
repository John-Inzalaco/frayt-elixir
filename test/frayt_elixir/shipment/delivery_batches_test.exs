defmodule FraytElixir.Shipment.DeliveryBatchesTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment.{
    DeliveryBatch,
    DeliveryBatches,
    MatchStop,
    DeliveryBatchSupervisor,
    MatchStopItem,
    Address
  }

  alias FraytElixir.Accounts.{Company, Location, Shipper}
  alias FraytElixir.Repo

  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup :start_match_supervisor

  setup do
    start_batch_webhook_sender(self())

    {:ok, _pid} = start_supervised(DeliveryBatchSupervisor)
    :ok
  end

  describe "list_batches/1" do
    test "lists batches" do
      insert_list(5, :delivery_batch)

      assert {[%DeliveryBatch{}, %DeliveryBatch{}], 2} =
               DeliveryBatches.list_batches(%{
                 order_by: :inserted_at,
                 order: :desc,
                 page: 1,
                 per_page: 3,
                 state: nil,
                 query: nil
               })
    end
  end

  describe "create_delivery_batch/2" do
    @valid_attrs %{
      origin_address: "1266 Norman Ave Cincinnati OH 45231",
      contract: nil,
      service_level: 1,
      pickup_at: ~N[2030-01-01 00:00:00],
      pickup_notes: "notes",
      po: "po number",
      stops: [
        %{
          delivery_notes: "Ring for #4",
          recipient: %{
            email: "test@frayt.com",
            name: "Burt Macklin",
            phone_number: "+15134020000"
          },
          has_load_fee: false,
          destination_address: "641 Evangeline Rd Cincinnati OH 45240",
          tip_price: 1000,
          items: [
            %{
              weight: "25",
              length: "10",
              width: "10",
              height: "10",
              pieces: "1",
              description: "A suspicious cube"
            },
            %{
              weight: "50",
              length: "20",
              width: "20",
              height: "20",
              pieces: "1",
              description: "A suspicious sphere"
            }
          ]
        },
        %{
          has_load_fee: true,
          destination_address: "641 Evangeline Rd Cincinnati OH 45240",
          items: [
            %{
              weight: "25",
              length: "10",
              width: "10",
              height: "10",
              pieces: "1",
              description: "A suspicious cube"
            },
            %{
              weight: "50",
              length: "20",
              width: "20",
              height: "20",
              pieces: "1",
              description: "A suspicious sphere"
            }
          ]
        }
      ]
    }

    test "with valid data creates delivery batch" do
      %{id: shipper_id} = shipper = insert(:shipper)

      assert {:ok,
              %DeliveryBatch{
                shipper: %Shipper{id: ^shipper_id},
                address: %Address{
                  formatted_address: "1266 Norman Ave Cincinnati OH 45231"
                },
                po: "po number",
                service_level: 1,
                pickup_at: ~U[2030-01-01 00:00:00Z],
                pickup_notes: "notes",
                match_stops: [
                  %{
                    delivery_notes: "Ring for #4",
                    recipient: %{
                      email: "test@frayt.com",
                      name: "Burt Macklin",
                      phone_number: %ExPhoneNumber.Model.PhoneNumber{
                        country_code: 1,
                        national_number: 513_402_0000
                      }
                    },
                    has_load_fee: false,
                    destination_address: %Address{
                      formatted_address: "641 Evangeline Rd Cincinnati OH 45240"
                    },
                    tip_price: 1000,
                    items: [
                      %{
                        weight: 25.0,
                        length: 10.0,
                        width: 10.0,
                        height: 10.0,
                        pieces: 1,
                        description: "A suspicious cube"
                      },
                      %{
                        weight: 50.0,
                        length: 20.0,
                        width: 20.0,
                        height: 20.0,
                        pieces: 1,
                        description: "A suspicious sphere"
                      }
                    ]
                  }
                  | _
                ]
              }} = DeliveryBatches.create_delivery_batch(@valid_attrs, shipper, route: false)
    end
  end

  describe "create_delivery_batch_from_csv/2" do
    test "with valid data creates delivery batch" do
      csv = %Plug.Upload{
        # content_type: ""
        path: "test/fixtures/deliveries.csv",
        filename: "deliveries.csv"
      }

      %Company{locations: [%Location{id: location_id, address_id: address_id}]} =
        insert(:company,
          locations: [
            insert(:location, schedule: insert(:schedule, sla: 120), shippers: [insert(:shipper)])
          ]
        )

      assert {:ok, %DeliveryBatch{id: delivery_batch_id}} =
               DeliveryBatches.create_delivery_batch_from_csv(
                 %{"location_id" => location_id, "pickup_at" => "2020-04-17T11:00:00.000Z"},
                 csv,
                 route: false
               )

      assert %DeliveryBatch{
               match_stops: match_stops,
               location_id: ^location_id,
               address_id: ^address_id,
               state: :pending
             } =
               Repo.get(DeliveryBatch, delivery_batch_id)
               |> Repo.preload(match_stops: [:items, :recipient])

      assert [match_stop1 | _] = match_stops

      assert %MatchStop{
               recipient: %{name: "jessie graham"},
               items: [
                 %MatchStopItem{}
               ]
             } = match_stop1
    end

    # TODO: temporary fix. Google API can only handle 9 stops, we need to move to a new API.
    @tag :skip
    test "with large batch starts optimizing routes" do
      csv = %Plug.Upload{
        # content_type: ""
        path: "test/fixtures/deliveries_large.csv",
        filename: "deliveries_large.csv"
      }

      %Company{locations: [%Location{id: location_id} = location]} =
        insert(:company_with_location)

      insert(:schedule_with_drivers, location: location)

      assert {:ok, %DeliveryBatch{id: delivery_batch_id}} =
               DeliveryBatches.create_delivery_batch_from_csv(
                 %{"location_id" => location_id, "pickup_at" => "2020-04-17T11:00:00.000Z"},
                 csv,
                 route: false
               )

      :timer.sleep(100)

      assert %DeliveryBatch{
               location_id: ^location_id,
               state: :pending
             } = Repo.get(DeliveryBatch, delivery_batch_id) |> Repo.preload(:match_stops)
    end
  end

  describe "build_match_stop_items/1" do
    test "builds volume based off dimensions given" do
      %{width: w, length: l, height: h, pieces: p} = _match_stop_item = insert(:match_stop_item)

      assert %{items: [%{}] = match_stop_items} =
               DeliveryBatches.build_match_stop_items(%{
                 width: w,
                 length: l,
                 height: h,
                 pieces: p,
                 description: "",
                 weight: 200
               })

      assert match_stop_items |> List.first() |> Map.get(:volume) == w * l * h * p
    end
  end

  describe "build_schedule_sla_timer/3" do
    test "adds the scheduled dropoff as the dropoff by for match_stops" do
      dropoff_by = ~N[2020-10-01 00:00:00]

      assert %{dropoff_by: ^dropoff_by} =
               DeliveryBatches.build_schedule_sla_timer(
                 %{scheduled_dropoff: dropoff_by |> NaiveDateTime.to_iso8601()},
                 nil,
                 nil
               )
    end

    test "adds an amount to a pickup time if no scheduled dropoff is present" do
      schedule = insert(:schedule, sla: 240)
      pickup_at = NaiveDateTime.utc_now()
      dropoff_by = NaiveDateTime.add(pickup_at, 240 * 60)

      assert %{dropoff_by: ^dropoff_by} =
               DeliveryBatches.build_schedule_sla_timer(
                 %{scheduled_dropoff: ""},
                 schedule,
                 pickup_at
               )
    end
  end

  describe "parse/1" do
    test "parse parses integer" do
      assert DeliveryBatches.parse("") == 1
      assert DeliveryBatches.parse("+") == 1
      assert DeliveryBatches.parse("5+") == 5
      assert DeliveryBatches.parse("3") == 3
      assert DeliveryBatches.parse(2) == 2
    end
  end

  describe "cancel_delivery_batch/1" do
    test "cancels a currently pending delivery batch" do
      batch = insert(:delivery_batch, state: :pending)
      batch = DeliveryBatches.get_delivery_batch(batch.id)

      assert {:ok, %DeliveryBatch{state: :canceled}} =
               DeliveryBatches.cancel_delivery_batch(batch)
    end

    test "deletes matches associated with a delivery batch" do
      batch = insert(:delivery_batch_completed, state: :pending)

      batch =
        DeliveryBatches.get_delivery_batch(batch.id)
        |> Repo.preload(matches: [:match_stops])

      assert {:ok, %DeliveryBatch{matches: matches}} =
               DeliveryBatches.cancel_delivery_batch(batch)

      assert matches |> Enum.all?(fn %{state: state} -> state == :canceled end)
    end
  end
end
