defmodule FraytElixirWeb.Admin.DeliveryBatchControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper
  import FraytElixir.Factory

  import FraytElixir.Test.StartMatchSupervisor

  import FraytElixir.Test.WebhookHelper
  import Ecto.Query

  alias FraytElixir.Repo
  alias FraytElixir.Accounts.{Company, Location}

  alias FraytElixir.Shipment.{DeliveryBatch, DeliveryBatchSupervisor}
  setup :start_match_supervisor

  describe "create deliveries for location" do
    setup :login_as_admin

    setup do
      start_batch_webhook_sender(self())
      {:ok, _spid} = start_supervised({Task.Supervisor, name: DeliveryBatchSupervisor})
      :ok
    end

    test "with valid data", %{
      conn: conn
    } do
      %Company{locations: [%Location{id: location_id}]} = insert(:company_with_location)

      params = %{
        "deliveries" => %{
          "location_id" => location_id,
          "pickup_at" => "2020-04-17T11:00:00.000Z",
          "csv" => %Plug.Upload{
            filename: "deliveries.csv",
            path: "test/fixtures/deliveries.csv"
          }
        }
      }

      conn =
        post(
          conn,
          Routes.delivery_batch_path(conn, :create),
          params
        )

      assert redirected_to(conn) =~ Routes.batches_path(conn, :index)

      delivery_batches =
        Repo.all(
          from db in DeliveryBatch, where: db.location_id == type(^location_id, :binary_id)
        )

      assert Enum.count(delivery_batches) == 1
    end

    test "with invalid data", %{
      conn: conn
    } do
      %Company{locations: [%Location{id: location_id}]} = insert(:company_with_location)

      params = %{
        "deliveries" => %{
          "location_id" => location_id,
          "pickup_at" => "2020-04-17T11:00:00.000Z",
          "csv" => %Plug.Upload{
            filename: "bonuses.csv",
            path: "test/fixtures/bonuses.csv"
          }
        }
      }

      conn =
        post(
          conn,
          Routes.delivery_batch_path(conn, :create),
          params
        )

      assert redirected_to(conn) == Routes.create_multistop_path(conn, :create)

      delivery_batches =
        Repo.all(
          from db in DeliveryBatch, where: db.location_id == type(^location_id, :binary_id)
        )

      assert Enum.empty?(delivery_batches)
    end
  end
end
