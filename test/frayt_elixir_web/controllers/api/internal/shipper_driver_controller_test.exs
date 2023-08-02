defmodule FraytElixirWeb.API.Internal.ShipperDriverControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper
  import FraytElixir.Factory

  alias FraytElixirWeb.DisplayFunctions

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "returns a list of past drivers for a shipper when no filter params are provided", %{
      conn: conn
    } do
      shipper = insert(:shipper, state: "approved")
      expected_driver_count = 3

      expected_response =
        for _ <- 1..expected_driver_count do
          %{driver: %{user: user, vehicles: [vehicle]} = driver} =
            insert(:completed_match, shipper: shipper)

          %{
            "current_location" => nil,
            "email" => user.email,
            "first_name" => driver.first_name,
            "id" => driver.id,
            "last_name" => DisplayFunctions.get_shortened_initial(driver.last_name),
            "phone_number" => DisplayFunctions.format_phone(driver.phone_number),
            "vehicle" => %{
              "id" => vehicle.id,
              "vehicle_class" => vehicle.vehicle_class,
              "vehicle_make" => vehicle.make,
              "vehicle_model" => vehicle.model,
              "vehicle_year" => vehicle.year
            }
          }
        end

      conn =
        conn
        |> add_token_for_shipper(shipper)
        |> get(Routes.api_v2_shipper_shipper_driver_path(conn, :index, ".1"))

      assert json_response(conn, 200)["data"] -- expected_response == []
    end

    test "does not return drivers that have not successfully completed a match when no filter params are provided",
         %{conn: conn} do
      shipper = insert(:shipper, state: "approved")

      driver = insert(:driver)

      insert(:canceled_match, shipper: shipper, driver: driver)

      conn =
        conn
        |> add_token_for_shipper(shipper)
        |> get(Routes.api_v2_shipper_shipper_driver_path(conn, :index, ".1"))

      assert json_response(conn, 200)["data"] == []
    end

    test "filters drivers by email with email filter param", %{conn: conn} do
      email = "expected_driver@email.com"
      shipper = insert(:shipper, state: "approved")
      %{vehicles: [vehicle]} = driver = insert(:driver, user: build(:user, email: email))
      _decoy_driver = insert(:driver, user: build(:user, email: "decoy_driver@email.com"))

      conn =
        conn
        |> add_token_for_shipper(shipper)
        |> get(
          Routes.api_v2_shipper_shipper_driver_path(conn, :index, ".1", %{
            email: email
          })
        )

      assert json_response(conn, 200)["data"] == [
               %{
                 "current_location" => nil,
                 "email" => driver.user.email,
                 "first_name" => driver.first_name,
                 "id" => driver.id,
                 "last_name" => DisplayFunctions.get_shortened_initial(driver.last_name),
                 "phone_number" => DisplayFunctions.format_phone(driver.phone_number),
                 "vehicle" => %{
                   "id" => vehicle.id,
                   "vehicle_class" => vehicle.vehicle_class,
                   "vehicle_make" => vehicle.make,
                   "vehicle_model" => vehicle.model,
                   "vehicle_year" => vehicle.year
                 }
               }
             ]
    end

    test "does not return drivers blocked from shipper when filtering by email",
         %{conn: conn} do
      shipper = insert(:shipper)

      %{user: %{email: email}} = hidden_driver = insert(:driver)

      insert(:hidden_customer, driver: hidden_driver, shipper: shipper)

      conn =
        conn
        |> add_token_for_shipper(shipper)
        |> get(
          Routes.api_v2_shipper_shipper_driver_path(conn, :index, ".1", %{
            email: email
          })
        )

      assert json_response(conn, 200)["data"] == []
    end

    test "does not return drivers blocked from company when filtering by email",
         %{conn: conn} do
      %{location: %{company: company}} = shipper = insert(:shipper_with_location)

      %{user: %{email: email}} = hidden_driver = insert(:driver)

      insert(:hidden_customer, driver: hidden_driver, company: company)

      conn =
        conn
        |> add_token_for_shipper(shipper)
        |> get(
          Routes.api_v2_shipper_shipper_driver_path(conn, :index, ".1", %{
            email: email
          })
        )

      assert json_response(conn, 200)["data"] == []
    end
  end
end
