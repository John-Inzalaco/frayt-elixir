defmodule FraytElixirWeb.API.Internal.VehicleControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Drivers.{Vehicle, Driver}

  import FraytElixir.Factory
  import FraytElixirWeb.Test.LoginHelper

  @update_cargo_capacity_attrs %{
    "capacity_between_wheel_wells" => 12,
    "capacity_door_height" => 10,
    "capacity_door_width" => 4,
    "capacity_height" => 12,
    "capacity_length" => 12,
    "capacity_weight" => 12,
    "capacity_width" => 12,
    "lift_gate" => false,
    "pallet_jack" => false
  }

  @invalid_cargo_capacity_attrs %{
    "capacity_between_wheel_wells" => nil,
    "capacity_door_height" => nil,
    "capacity_door_width" => nil,
    "capacity_height" => nil,
    "capacity_length" => nil,
    "capacity_weight" => nil,
    "capacity_width" => nil,
    "lift_gate" => nil,
    "pallet_jack" => nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "update vehicle cargo capacity" do
    setup [:login_as_unregistered_driver]

    test "renders vehicle with valid data", %{
      conn: conn,
      unregistered_driver: %Driver{
        vehicles: [
          %Vehicle{
            id: vehicle_id,
            make: make,
            model: model,
            year: year,
            vehicle_class: vehicle_class
          } = vehicle
          | _
        ]
      }
    } do
      conn =
        put(
          conn,
          Routes.api_v2_driver_vehicle_path(conn, :update, ".1", vehicle),
          @update_cargo_capacity_attrs
        )

      assert %{
               "id" => ^vehicle_id,
               "vehicle_make" => ^make,
               "vehicle_model" => ^model,
               "vehicle_year" => ^year,
               "vehicle_class" => ^vehicle_class,
               "capacity_between_wheel_wells" => 12,
               "capacity_door_height" => 10,
               "capacity_door_width" => 4,
               "capacity_height" => 12,
               "capacity_length" => 12,
               "capacity_weight" => 12,
               "capacity_width" => 12,
               "lift_gate" => false,
               "pallet_jack" => false
             } = json_response(conn, 200)["response"]
    end

    test "renders error with invalid data", %{
      conn: conn,
      unregistered_driver: %Driver{
        vehicles: [%Vehicle{} = vehicle | _]
      }
    } do
      conn =
        put(
          conn,
          Routes.api_v2_driver_vehicle_path(conn, :update, ".1", vehicle),
          @invalid_cargo_capacity_attrs
        )

      assert %{"code" => "invalid_attributes"} = json_response(conn, 422)
    end

    test "renders error when accessed by unauthorized driver", %{conn: conn} do
      vehicle = insert(:vehicle)

      conn =
        put(
          conn,
          Routes.api_v2_driver_vehicle_path(conn, :update, ".1", vehicle),
          @invalid_cargo_capacity_attrs
        )

      assert %{"message" => "Unauthorized"} = json_response(conn, 401)
    end
  end

  describe "update vehicle dismissed capacity" do
    setup [:login_as_unregistered_driver]

    test "renders vehicle with valid data", %{
      conn: conn,
      unregistered_driver: %Driver{
        vehicles: [%Vehicle{id: vehicle_id} = vehicle | _]
      }
    } do
      conn =
        patch(
          conn,
          Routes.api_v2_driver_vehicle_action_path(conn, :dismiss_capacity, ".1", vehicle)
        )

      assert %{
               "id" => ^vehicle_id,
               "capacity_dismissed_at" => _updated_at
             } = json_response(conn, 200)["response"]
    end

    test "renders error when accessed by unauthorized driver", %{conn: conn} do
      vehicle = insert(:vehicle)

      conn =
        patch(
          conn,
          Routes.api_v2_driver_vehicle_action_path(conn, :dismiss_capacity, ".1", vehicle)
        )

      assert %{"message" => "Unauthorized"} = json_response(conn, 401)
    end
  end

  describe "vehicle step on driver registration" do
    setup [:login_as_unregistered_driver]

    test "create will success when valid params", %{conn: conn} do
      params = %{
        insurance_photo: Base.encode64("image_content"),
        registration_photo: Base.encode64("image_content"),
        insurance_expiration_date: "2030-01-01",
        registration_expiration_date: "2030-01-01",
        make: "vehicle_make",
        model: "vehicle_model",
        year: 2022,
        vin: "vehicle_vin",
        vehicle_class: 1,
        license_plate: "license_plate"
      }

      conn = post(conn, Routes.api_v2_driver_vehicle_path(conn, :create, ".1", vehicle: params))
      assert %{"vehicle_class" => 1, "id" => _} = json_response(conn, 201)["response"]
    end

    test "create will fail when missing or invalid params", %{conn: conn} do
      params = %{
        insurance_photo: Base.encode64("image_content"),
        registration_photo: Base.encode64("image_content"),
        insurance_expiration_date: "2030-01-01",
        registration_expiration_date: "2030-01-01",
        make: nil,
        model: nil,
        year: nil,
        vin: nil,
        vehicle_class: -1,
        license_plate: nil
      }

      conn = post(conn, Routes.api_v2_driver_vehicle_path(conn, :create, ".1", vehicle: params))

      assert %{
               "code" => "invalid_attributes",
               "message" => _
             } = json_response(conn, 422)
    end

    test "update will success when valid params", %{conn: conn} do
      %{vehicles: [%{id: vehicle_id}]} =
        driver =
        insert(:driver, vehicles: [build(:vehicle, make: "Honda", model: "CRV", year: 2022)])

      params = %{
        insurance_photo: Base.encode64("image_content"),
        registration_photo: Base.encode64("image_content"),
        insurance_expiration_date: "2030-01-01",
        registration_expiration_date: "2030-01-01",
        make: "vehicle_make",
        model: "vehicle_model",
        year: 2022,
        vin: "vehicle_vin",
        vehicle_class: 1,
        license_plate: "license_plate"
      }

      {:ok, conn: conn} = login_as(conn, driver)

      conn =
        put(
          conn,
          Routes.api_v2_driver_vehicle_path(conn, :update, ".1", vehicle_id),
          %{"vehicle" => params}
        )

      assert %{"id" => ^vehicle_id, "vehicle_make" => "vehicle_make"} =
               json_response(conn, 200)["response"]
    end

    test "update will fail when missing or invalid params", %{conn: conn} do
      %{vehicles: [%{id: vehicle_id}]} =
        driver =
        insert(:driver, vehicles: [build(:vehicle, make: "Honda", model: "CRV", year: 2022)])

      {:ok, conn: conn} = login_as(conn, driver)

      params = %{
        insurance_photo: Base.encode64("image_content"),
        registration_photo: Base.encode64("image_content"),
        insurance_expiration_date: "2030-01-01",
        registration_expiration_date: "2030-01-01",
        make: nil,
        model: nil,
        year: nil,
        vin: nil,
        vehicle_class: -1,
        license_plate: nil
      }

      conn =
        put(
          conn,
          Routes.api_v2_driver_vehicle_path(conn, :update, ".1", vehicle_id),
          %{"vehicle" => params}
        )

      assert %{
               "code" => "invalid_attributes",
               "message" =>
                 "License plate can't be blank; Make can't be blank; Model can't be blank; Vin can't be blank; Year can't be blank"
             } = json_response(conn, 422)
    end
  end

  defp login_as_unregistered_driver(%{conn: conn}) do
    driver = insert(:unregistered_driver)
    conn = add_token_for_driver(conn, driver)
    {:ok, conn: conn, unregistered_driver: driver}
  end

  defp login_as(conn, driver) do
    conn = add_token_for_driver(conn, driver)
    {:ok, conn: conn}
  end
end
