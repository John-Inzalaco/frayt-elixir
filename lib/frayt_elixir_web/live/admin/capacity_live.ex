defmodule FraytElixirWeb.Admin.CapacityLive do
  use FraytElixirWeb, :live_view
  use FraytElixirWeb.ModalEvents

  use FraytElixirWeb.DataTable,
    base_url: "/admin/markets/capacity",
    default_filters: %{order_by: :updated_at},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :pickup_address, type: :string, default: nil},
      %{key: :vehicle_types, type: {:list, :integer}, default: [1, 2, 3, 4]},
      %{key: :pickup_point, type: :any, default: nil},
      %{key: :search_radius, type: :integer, default: nil},
      %{key: :driver_location, type: :atom, default: :current_location}
    ],
    model: :capacity,
    handle_params: :none,
    init_on_mount: false

  alias FraytElixir.Notifications.DriverNotification
  alias FraytElixir.{Drivers, MatchSupervisor, Shipment}
  alias Shipment.Match
  alias FraytElixirWeb.DisplayFunctions
  alias Phoenix.PubSub
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

  def mount(_params, %{"match_id" => match_id}, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      :ok = PubSub.subscribe(FraytElixir.PubSub, "notification_batch:#{match_id}")
      match = Shipment.get_match(match_id)

      socket =
        init_data_table(socket, %{
          vehicle_types: Enum.to_list(match.vehicle_class..4),
          pickup_point: match.origin_address.geo_location,
          search_radius: 20
        })

      {:ok,
       assign(socket, %{
         error: nil,
         capacity_error: nil,
         api_key: Application.get_env(:google_maps, :api_key),
         match: match,
         show_modal: false
       })}
    end)
  end

  def mount(_params, _session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      socket = init_data_table(socket)

      {:ok,
       assign(socket, %{
         api_key: Application.get_env(:google_maps, :api_key),
         error: nil,
         show_modal: false,
         capacity_error: nil
       })}
    end)
  end

  def handle_event(
        "assign_driver",
        %{"driverid" => driver_id},
        %{assigns: %{match: %Match{id: id} = match}} = socket
      ) do
    live_view_action(__MODULE__, "assign_driver", socket, fn ->
      match =
        if match.state == :scheduled do
          Shipment.MatchWorkflow.force_transition_state(match, :assigning_driver)
        else
          Shipment.get_match!(id)
        end

      driver = Drivers.get_driver!(driver_id, :no_matches)
      override_driver = not is_nil(match.driver)
      updated_match = Drivers.assign_match(match, driver, override_driver)

      {:ok, _} = DriverNotification.send_removed_from_match_notification(match.driver, match)

      updated_match
      |> case do
        {:ok, updated_match} ->
          send(socket.parent_pid, {:updated_match, updated_match})
          {:noreply, assign(socket, %{match: updated_match})}

        {:error, error} ->
          send(
            socket.parent_pid,
            {:send_alert, :danger, DisplayFunctions.humanize_update_errors(error, "Match")}
          )

          {:noreply, socket}
      end
    end)
  end

  def handle_event("send_notifications", _event, socket) do
    live_view_action(__MODULE__, "send_notifications", socket, fn ->
      MatchSupervisor.start_assigning_drivers(socket.assigns.match)
      {:noreply, put_flash(socket, :info, "Drivers have been notified.")}
    end)
  end

  def handle_info(
        {:sent_texts,
         %{
           attempted: attempted,
           failed_message: failed_message,
           succeeded: succeeded
         }},
        socket
      ) do
    live_view_action(__MODULE__, "sent_texts", socket, fn ->
      send(
        socket.parent_pid,
        {:send_alert, :info,
         "Successfully notified #{succeeded}/#{attempted} drivers. #{failed_message}"}
      )

      {:noreply, assign(socket, :show_modal, false)}
    end)
  end

  def handle_info({:new_notification_batch, batch}, %{assigns: %{match: match}} = socket) do
    live_view_action(__MODULE__, "new_notification_batch", socket, fn ->
      notification_batches = match.notification_batches ++ [batch]

      {:noreply,
       assign(socket, %{
         match: %Match{
           match
           | notification_batches: notification_batches
         }
       })}
    end)
  end

  def render(%{match: _match} = assigns) do
    FraytElixirWeb.Admin.CapacityView.render("assign_driver.html", assigns)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.CapacityView.render("index.html", assigns)
  end

  def list_records(%{assigns: %{match: %Match{}}} = socket, filters) do
    {capacity, last_page, capacity_state} = Drivers.list_capacity(filters)

    {assign_state(socket, capacity_state), {capacity, last_page}}
  end

  def list_records(socket, filters) do
    {capacity, last_page, updated_state} = Drivers.list_capacity(filters)

    {assign_state(socket, updated_state), {capacity, last_page}}
  end

  defp assign_state(socket, updated_state) do
    new_filters = Map.take(updated_state, @filter_keys)
    new_state = Map.drop(updated_state, @filter_keys)

    socket
    |> assign_data_table(:filters, Map.merge(socket.assigns.data_table.filters, new_filters))
    |> assign(new_state)
  end
end
