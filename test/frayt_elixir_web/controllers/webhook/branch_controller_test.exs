defmodule FraytElixirWeb.Webhook.BranchControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Repo
  alias FraytElixir.Drivers.Driver

  describe "handle_webhook" do
    test "updates claimed webhook", %{conn: conn} do
      driver = insert(:driver, wallet_state: :UNCLAIMED)
      data = request_data("ORGANIZATION_INITIALIZED_ACCOUNT_CLAIMED", %{employee_id: driver.id})
      conn = post(conn, Routes.webhook_branch_path(conn, :handle_webhooks), data)

      assert %{
               "data" => %{
                 "message" => "Successfully saved changes"
               }
             } = json_response(conn, 200)

      assert %Driver{wallet_state: :ACTIVE} = Repo.get(Driver, driver.id)
    end

    test "updates created webhook", %{conn: conn} do
      driver = insert(:driver, wallet_state: nil)
      data = request_data("ORGANIZATION_INITIALIZED_ACCOUNT_CREATED", %{employee_id: driver.id})
      conn = post(conn, Routes.webhook_branch_path(conn, :handle_webhooks), data)

      assert %{
               "data" => %{
                 "message" => "Successfully saved changes"
               }
             } = json_response(conn, 200)

      assert %Driver{wallet_state: :UNCLAIMED} = Repo.get(Driver, driver.id)
    end

    test "returns bad request for missing driver", %{conn: conn} do
      data =
        request_data("ORGANIZATION_INITIALIZED_ACCOUNT_CREATED", %{
          employee_id: "276b7125-830d-4074-9afb-afcf3aa6808c"
        })

      conn = post(conn, Routes.webhook_branch_path(conn, :handle_webhooks), data)

      assert %{"message" => "No Driver found with given employee_id"} = json_response(conn, 400)
    end

    test "returns bad request for unhandled event", %{conn: conn} do
      data = request_data("ACCOUNT_VERIFIED_AS_WORKER", %{})

      conn = post(conn, Routes.webhook_branch_path(conn, :handle_webhooks), data)

      assert %{"message" => "Invalid event id"} = json_response(conn, 400)
    end

    test "returns forbidden for invalid encryption", %{conn: conn} do
      data = %{
        "event" => "ORGANIZATION_INITIALIZED_ACCOUNT_CREATED",
        "client_type" => "ORGANIZATION",
        "client_id" => 1,
        "data" => "qwerty"
      }

      conn = post(conn, Routes.webhook_branch_path(conn, :handle_webhooks), data)

      assert %{"code" => "forbidden"} = json_response(conn, 403)
    end
  end

  defp request_data(event_type, data),
    do: %{
      "event" => event_type,
      "client_type" => "ORGANIZATION",
      "client_id" => 1,
      "data" => encrypt(data)
    }

  defp encrypt(data) do
    data = data |> Jason.encode!()

    key = Application.get_env(:frayt_elixir, :branch_aes_key) |> Base.decode64!()

    {:ok, {init_vec, cipher_data}} = ExCrypto.encrypt(key, data)

    Base.encode64(init_vec <> cipher_data)
  end
end
