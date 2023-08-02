defmodule FraytElixirWeb.API.Internal.ScheduleController do
  use FraytElixirWeb, :controller
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.{DriverSchedule, Schedule}
  alias FraytElixir.Drivers.Driver
  alias FraytElixirWeb.SessionHelper

  action_fallback FraytElixirWeb.FallbackController

  def show(conn, %{"id" => id}) do
    case Accounts.get_schedule(id) do
      %Schedule{} = schedule -> render(conn, "show.json", schedule: schedule)
      nil -> {:error, :not_found}
    end
  end

  def available(conn, _params) do
    with %Driver{} = driver <- SessionHelper.get_current_driver(conn),
         schedules <- Accounts.list_unaccepted_schedules_for_driver(driver) do
      render(conn, "index.json", schedules: schedules)
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  def update(
        conn,
        %{
          "id" => schedule_id,
          "opt_in" => "true"
        }
      ) do
    with %Driver{id: driver_id} <- SessionHelper.get_current_driver(conn),
         {:ok, %DriverSchedule{}} <-
           Accounts.add_driver_to_schedule(%{schedule_id: schedule_id, driver_id: driver_id}),
         schedule <- Accounts.get_schedule(schedule_id) do
      render(conn, "show.json", schedule: schedule)
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  def update(
        conn,
        %{
          "id" => schedule_id,
          "opt_in" => "false"
        }
      ) do
    with %Driver{id: driver_id} <- SessionHelper.get_current_driver(conn),
         {:ok, %DriverSchedule{}} <-
           Accounts.remove_driver_from_schedule(schedule_id, driver_id),
         schedule <- Accounts.get_schedule(schedule_id) do
      render(conn, "show.json", schedule: schedule)
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end
end
