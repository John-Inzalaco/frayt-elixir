defmodule FraytElixirWeb.API.Internal.DriverLocationControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper
  alias FraytElixirWeb.Endpoint

  alias FraytElixir.Drivers.{DriverLocation, Driver}
  alias FraytElixir.Repo

  import Phoenix.ChannelTest

  # The default endpoint for testing
  @endpoint FraytElixirWeb.Endpoint

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create driver_location" do
    setup [:login_as_driver]

    test "renders driver_location when data is valid", %{conn: conn, driver: driver} do
      front_end_request = %{
        "latitude" => 120.5,
        "longitude" => 120.5
      }

      Endpoint.subscribe("driver_locations:#{driver.id}")

      conn =
        post(
          conn,
          Routes.api_v2_driver_location_path(conn, :create, ".1"),
          front_end_request
        )

      assert %{
               "lat" => 120.5,
               "lng" => 120.5
             } = json_response(conn, 201)["response"]

      assert %Driver{
               current_location: %DriverLocation{
                 geo_location: %Geo.Point{coordinates: {120.5, 120.5}}
               }
             } = Repo.get(Driver, driver.id) |> Repo.preload(:current_location)

      refute_broadcast(
        "driver_location",
        %DriverLocation{
          geo_location: %Geo.Point{coordinates: {120.5, 120.5}}
        },
        250
      )
    end

    test "multiple updates for same driver", %{conn: conn} do
      front_end_request = %{
        "latitude" => 120.5,
        "longitude" => 120.5
      }

      conn =
        post(
          conn,
          Routes.api_v2_driver_location_path(conn, :create, ".1"),
          front_end_request
        )

      assert %{
               "lat" => 120.5,
               "lng" => 120.5
             } = json_response(conn, 201)["response"]

      conn =
        post(conn, Routes.api_v2_driver_location_path(conn, :create, ".1"), %{
          "latitude" => 39,
          "longitude" => -85
        })

      assert json_response(conn, 201)
    end
  end
end
