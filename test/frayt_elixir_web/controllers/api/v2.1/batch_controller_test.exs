defmodule FraytElixirWeb.API.V2x1.BatchControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{DeliveryBatches, DeliveryBatchSupervisor}
  alias FraytElixir.Accounts.ApiAccount
  import FraytElixirWeb.Test.LoginHelper

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    start_batch_webhook_sender(self())
  end

  setup :start_match_supervisor

  @batch_params %{
    origin_address: "1266 Norman Ave Cincinnati OH 45231",
    pickup_at: "2030-01-01T00:00:00Z",
    complete_by: "2030-01-01T12:00:00Z",
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
        ],
        destination_photo_required: false
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
        ],
        destination_photo_required: false
      }
    ]
  }

  describe "show batch" do
    setup :login_with_api

    test "returns batch", %{
      conn: conn,
      api_account: %ApiAccount{company: %{locations: [%{shippers: [shipper]}]}}
    } do
      %{id: batch_id} = insert(:delivery_batch, shipper: shipper)

      conn = get(conn, RoutesApiV2_1.api_batch_path(conn, :show, batch_id))

      assert %{"response" => %{"id" => ^batch_id}} = json_response(conn, 200)
    end
  end

  describe "create batch of matches" do
    setup :login_with_api

    setup do
      {:ok, _spid} = start_supervised({Task.Supervisor, name: DeliveryBatchSupervisor})
      :ok
    end

    test "multistop", %{
      conn: conn,
      api_account: %ApiAccount{company: _company}
    } do
      conn = post(conn, RoutesApiV2_1.api_batch_path(conn, :create), @batch_params)

      :timer.sleep(600)

      assert %{
               "complete_by" => "2030-01-01T12:00:00Z",
               "state" => "pending",
               "state_transition" => nil
             } = json_response(conn, 201)["response"]
    end
  end

  describe "cancel batch of matches" do
    setup :login_with_api

    setup do
      {:ok, _spid} = start_supervised({Task.Supervisor, name: DeliveryBatchSupervisor})
      :ok
    end

    test "cancels batch and cancels all created matches associated with it", %{
      conn: conn,
      api_account: %ApiAccount{
        company: %{locations: [%{schedule: schedule, shippers: [shipper]}]}
      }
    } do
      %{id: batch_id, matches: [%{id: match_id}]} =
        batch =
        insert(:delivery_batch,
          state: :routing_complete,
          shipper: shipper,
          matches: [build(:match, schedule: schedule)]
        )

      conn = delete(conn, RoutesApiV2_1.api_batch_path(conn, :delete, batch))
      assert %{"response" => %{"id" => ^batch_id}} = json_response(conn, 200)
      assert %{state: :canceled} = DeliveryBatches.get_delivery_batch(batch_id)
      assert %{state: :canceled} = Shipment.get_match!(match_id)
    end

    test "cancels batch when it is currently in progress of routing", %{
      conn: conn,
      api_account: %ApiAccount{}
    } do
      conn = post(conn, RoutesApiV2_1.api_batch_path(conn, :create), @batch_params)
      %{"id" => batch_id} = json_response(conn, 201)["response"]
      assert %{state: state} = DeliveryBatches.get_delivery_batch(batch_id)
      assert state != :canceled

      :timer.sleep(500)

      conn = delete(conn, RoutesApiV2_1.api_batch_path(conn, :delete, batch_id))
      assert %{"response" => %{"id" => ^batch_id}} = json_response(conn, 200)
      assert %{state: :canceled} = DeliveryBatches.get_delivery_batch(batch_id)
    end
  end
end
