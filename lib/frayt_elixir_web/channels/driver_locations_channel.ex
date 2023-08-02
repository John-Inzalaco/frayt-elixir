defmodule FraytElixirWeb.DriverLocationsChannel do
  use FraytElixirWeb, :channel
  use Appsignal.Instrumentation.Decorators
  alias FraytElixir.Drivers

  def join("driver_locations:" <> driver_id, payload, socket) do
    if authorized?(payload) do
      case Drivers.get_current_location(driver_id) do
        nil ->
          {:ok, socket}

        driver_location ->
          {:ok, driver_location, socket}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @decorate channel_action()
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (driver_locations:lobby).
  @decorate channel_action()
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
