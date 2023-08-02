defmodule FraytElixirWeb.API.Internal.DriverMatchStopControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Shipment.MatchStop
  alias FraytElixir.Drivers.Driver
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixirWeb.Test.LoginHelper
  import FraytElixirWeb.Test.FileHelper

  setup :start_match_supervisor

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "arrive at stop" do
    setup [:login_as_driver]

    test "driver drops off cargo", %{conn: conn, driver: driver} do
      %{coordinates: {lng, lat}} = gaslight_point()
      %{match_stops: [stop]} = match = insert(:en_route_to_dropoff_match, driver: driver)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_stop_path(conn, :update, ".1", match.id, stop), %{
          "state" => "arrived",
          "location" => %{"latitude" => lat, "longitude" => lng}
        })

      assert %{"state" => "picked_up", "stops" => [%{"state" => "arrived"}]} =
               json_response(conn, 200)["response"]
    end
  end

  describe "sign stop" do
    setup [:login_as_driver, :base64_image]

    test "with valid params, returns a match", %{
      conn: conn,
      driver: %Driver{id: driver_id} = driver,
      image: image
    } do
      %{match_stops: [stop]} = match = insert(:arrived_at_dropoff_match, driver: driver)

      conn =
        conn
        |> put(Routes.api_v2_driver_match_stop_path(conn, :update, ".1", match.id, stop), %{
          state: "signed",
          receiver_name: "Alex Heflin",
          user: driver_id,
          image: %{contents: image, filename: "signature"}
        })

      assert %{
               "state" => "picked_up",
               "stops" => [
                 %{
                   "signature_photo" => "" <> _,
                   "signature_name" => "Alex Heflin"
                 }
               ]
             } = json_response(conn, 200)["response"]
    end
  end

  describe "en_route_to_return" do
    setup [:login_as_driver, :create_match_stop]

    test "if any of the stop's state is undeliverable then the state of the match should be en_route_to_return",
         %{
           conn: conn,
           driver: driver
         } do
      FraytElixir.Drivers.update_current_location(driver, FraytElixir.Factory.london_point())

      match =
        %{match_stops: match_stops} =
        insert(:signed_match,
          driver: driver,
          match_stops: [build(:signed_match_stop), build(:undeliverable_match_stop)]
        )

      stop = match_stops |> Enum.find(&(&1.state != :undelivered))

      resp =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, "", match.id, stop), %{
          "state" => "delivered"
        })

      assert %{
               "state" => "en_route_to_return"
             } = json_response(resp, 200)["response"]

      resp =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match.id), %{
          "state" => "arrived_at_return"
        })

      assert %{
               "code" => "unprocessable_entity",
               "message" =>
                 "Your current location is not showing at the current address. Please restart your app if you feel this is incorrect. Contact the Frayt support team if the problem continues."
             } = json_response(resp, 422)
    end

    test "if driver press arrived_at_return when on the pickup point, it should be successfull",
         %{
           conn: conn,
           driver: driver
         } do
      FraytElixir.Drivers.update_current_location(driver, FraytElixir.Factory.gaslight_point())

      match =
        %{match_stops: match_stops} =
        insert(:signed_match,
          driver: driver,
          match_stops: [build(:signed_match_stop), build(:undeliverable_match_stop)]
        )

      stop = match_stops |> Enum.find(&(&1.state != :undelivered))

      resp =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, "", match.id, stop), %{
          "state" => "delivered"
        })

      assert %{
               "state" => "en_route_to_return"
             } = json_response(resp, 200)["response"]

      resp =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match.id), %{
          "state" => "arrived_at_return"
        })

      assert %{"state" => "arrived_at_return"} = json_response(resp, 200)["response"]
    end

    test "if driver press returned it should mark the match as completed",
         %{
           conn: conn,
           driver: driver
         } do
      FraytElixir.Drivers.update_current_location(driver, FraytElixir.Factory.gaslight_point())

      match =
        %{match_stops: match_stops} =
        insert(:signed_match,
          driver: driver,
          match_stops: [build(:signed_match_stop), build(:undeliverable_match_stop)]
        )

      stop = match_stops |> Enum.find(&(&1.state != :undelivered))

      resp =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, "", match.id, stop), %{
          "state" => "delivered"
        })

      assert %{
               "state" => "en_route_to_return"
             } = json_response(resp, 200)["response"]

      resp =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match.id), %{
          "state" => "arrived_at_return"
        })

      assert %{"state" => "arrived_at_return"} = json_response(resp, 200)["response"]

      resp =
        put(conn, Routes.api_v2_driver_match_path(conn, :update, ".1", match.id), %{
          "state" => "returned"
        })

      assert %{"state" => "completed"} = json_response(resp, 200)["response"]
    end
  end

  describe "deliver stop" do
    setup [:login_as_driver, :create_match_stop, :base64_image]

    test "renders match when delivered", %{
      conn: conn,
      match_stop: %MatchStop{match_id: match_id} = stop,
      match: match
    } do
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      conn =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, ".1", match_id, stop), %{
          "state" => "delivered"
        })

      assert %{
               "id" => ^match_id,
               "state" => "completed",
               "stops" => [%{"state" => "delivered"}]
             } = json_response(conn, 200)["response"]
    end

    test "uploads photo when delivered", %{
      conn: conn,
      match_stop: %MatchStop{match_id: match_id} = stop,
      image: image,
      match: match
    } do
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      conn =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, ".1", match_id, stop), %{
          "state" => "delivered",
          "destination_photo" => %{
            "contents" => image,
            "filename" => "test.jpg"
          }
        })

      assert %{
               "id" => ^match_id,
               "state" => "completed",
               "stops" => [
                 %{
                   "state" => "delivered",
                   "destination_photo" => _
                 }
               ]
             } = json_response(conn, 200)["response"]
    end

    test "renders errors when data is invalid", %{conn: conn, driver: driver} do
      %{id: match_id, match_stops: [stop | _]} = insert(:completed_match, driver: driver)

      conn =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, ".1", match_id, stop), %{
          "state" => "delivered"
        })

      assert %{
               "code" => "invalid_state"
             } = json_response(conn, 400)
    end
  end

  describe "undeliverable match" do
    setup [:login_as_driver, :create_match_stop]

    test "renders match when undeliverable", %{
      conn: conn,
      match_stop: %MatchStop{match_id: match_id} = stop,
      match: match
    } do
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      conn =
        put(conn, Routes.api_v2_driver_match_stop_path(conn, :update, ".1", match_id, stop), %{
          "state" => "undeliverable"
        })

      assert %{
               "id" => ^match_id,
               "stops" => [%{"state" => "undeliverable"}]
             } = json_response(conn, 200)["response"]
    end
  end

  describe "toggle en route" do
    setup [:login_as_driver]

    test "renders match when en route", %{conn: conn, driver: driver} do
      %{id: match_id, match_stops: [stop = %{id: stop_id} | _]} =
        insert(:en_route_to_dropoff_match, driver: driver)

      conn =
        put(
          conn,
          Routes.api_v2_driver_match_stop_action_path(
            conn,
            :toggle_en_route,
            ".1",
            match_id,
            stop
          )
        )

      assert %{
               "id" => ^match_id,
               "stops" => [
                 %{
                   "id" => ^stop_id,
                   "state" => "pending"
                 }
               ]
             } = json_response(conn, 200)["response"]
    end
  end

  defp create_match_stop(%{driver: driver}) do
    match =
      %{match_stops: [stop]} =
      insert(:signed_match,
        driver: driver,
        match_stops: [build(:signed_match_stop)]
      )

    {:ok, match_stop: stop, match: match}
  end
end
