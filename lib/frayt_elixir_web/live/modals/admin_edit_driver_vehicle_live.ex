defmodule FraytElixirWeb.AdminEditDriverVehicleLive do
  use Phoenix.LiveView
  import FraytElixir.AtomizeKeys
  alias FraytElixir.Drivers
  alias FraytElixir.Repo
  alias FraytElixir.Drivers.Vehicle

  def mount(_params, %{"vehicle" => vehicle, "driver" => driver}, socket) do
    {:ok,
     assign(socket, %{
       vehicle: vehicle,
       driver: driver,
       vehicle_changeset: Drivers.change_vehicle(vehicle)
     })}
  end

  def handle_event("toggle_edit", _event, socket) do
    send(socket.parent_pid, :close_edit)
    {:noreply, socket}
  end

  def handle_event(
        "update_vehicle",
        _,
        %{assigns: %{vehicle_changeset: changeset, driver: driver}, parent_pid: parent_pid} =
          socket
      ) do
    case Repo.update(changeset) do
      {:ok, vehicle} ->
        driver = %{driver | vehicles: sync_vehicles(driver, vehicle)}

        send(parent_pid, {:driver_updated, driver})

        {:noreply, assign(socket, %{vehicle_changeset: nil})}

      {:error, changeset} ->
        {:noreply, assign(socket, %{vehicle_changeset: changeset})}
    end
  end

  def handle_event(
        "change_vehicle",
        %{"vehicle" => vehicle_form},
        %{assigns: %{vehicle: vehicle}} = socket
      ),
      do:
        {:noreply,
         assign(
           socket,
           :vehicle_changeset,
           Vehicle.admin_changeset(vehicle, atomize_keys(vehicle_form))
         )}

  defp sync_vehicles(driver, vehicle) do
    Enum.map(driver.vehicles, fn v ->
      case v.id == vehicle.id do
        true -> vehicle
        false -> v
      end
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("edit_driver_vehicle.html", assigns)
  end
end
