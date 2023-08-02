defmodule FraytElixirWeb.API.Internal.DriverDeviceControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixir.Factory
  import FraytElixirWeb.Test.LoginHelper

  alias FraytElixir.Drivers

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "send_test_notification/2" do
    setup [:login_as_driver]

    test "returns success", %{conn: conn, driver: driver} do
      assert not is_nil(driver.default_device_id)

      conn =
        post(
          conn,
          Routes.api_v2_driver_driver_device_path(conn, :send_test_notification, ".1"),
          %{}
        )

      assert json_response(conn, 200)
    end
  end

  @device_attrs %{
    device_uuid: "device_uuid",
    device_model: "device_model",
    player_id: "onesignal",
    os: "os",
    os_version: "os_version",
    is_tablet: false,
    is_location_enabled: true,
    app_version: "1.0.0",
    app_revision: "52",
    app_build_number: 80
  }

  describe "create" do
    setup [:login_as_driver]

    test "creates device", %{conn: conn} do
      driver = insert(:driver_with_wallet, default_device: nil)

      conn = add_token_for_driver(conn, driver)

      conn =
        post(conn, Routes.api_v2_driver_device_path(conn, :create, ".1"), %{
          "device" => @device_attrs
        })

      assert json_response(conn, 200)["response"]
      %{"id" => device_id} = json_response(conn, 200)["response"]

      driver = Drivers.get_driver(driver.id)
      assert driver.default_device_id == device_id
    end
  end
end
