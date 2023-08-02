defmodule FraytElixirWeb.API.Internal.ScheduleControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Accounts.Schedule
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Notifications.DriverNotification
  alias FraytElixir.Drivers

  describe "show" do
    test "renders schedule", %{conn: conn} do
      %Schedule{id: schedule_id} = insert(:schedule)
      conn = get(conn, Routes.api_v2_schedule_path(conn, :show, ".1", schedule_id))

      assert %{"id" => ^schedule_id} = json_response(conn, 200)["response"]
    end
  end

  describe "available" do
    setup [:login_as_driver]

    test "renders list of available schedules for driver", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      insert(:driver_location, driver: driver, geo_location: chris_house_point())
      driver = set_driver_default_device(driver)
      Drivers.update_current_location(driver, chris_house_point())

      insert_list(5, :schedule)
      |> Enum.map(&DriverNotification.send_fleet_opportunity_notifications(&1, 90, true))

      conn = get(conn, Routes.api_v2_driver_schedules_schedule_path(conn, :available, ".1"))

      schedules = json_response(conn, 200)["response"]
      assert schedules |> Enum.count() == 5
    end
  end

  describe "update driver multistop schedule opt-in" do
    setup [:login_as_driver]

    test "with valid opt-in params, returns 200", %{conn: conn} do
      schedule = insert(:schedule)

      opt_in_params = %{
        "opt_in" => "true"
      }

      conn = put(conn, Routes.api_v2_schedule_path(conn, :update, ".1", schedule), opt_in_params)

      assert response(conn, 200)
    end

    test "opting in to schedule current driver has already joined returns error", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      schedule = insert(:schedule, drivers: [driver])

      opt_in_params = %{
        "opt_in" => "true"
      }

      conn = put(conn, Routes.api_v2_schedule_path(conn, :update, ".1", schedule), opt_in_params)

      assert %{
               "message" => "Already in fleet"
             } = json_response(conn, 422)
    end

    test "with valid opt-out params, returns 200", %{conn: conn, driver: %Driver{} = driver} do
      schedule = insert(:schedule, drivers: [driver])

      opt_out_params = %{
        "opt_in" => "false"
      }

      conn = put(conn, Routes.api_v2_schedule_path(conn, :update, ".1", schedule), opt_out_params)

      assert response(conn, 200)
    end

    test "opting out of schedule current driver has not joined returns error", %{
      conn: conn
    } do
      schedule = insert(:schedule_with_drivers)

      opt_out_params = %{
        "opt_in" => "false"
      }

      conn = put(conn, Routes.api_v2_schedule_path(conn, :update, ".1", schedule), opt_out_params)

      assert %{
               "message" => "Not in fleet"
             } = json_response(conn, 422)
    end
  end
end
