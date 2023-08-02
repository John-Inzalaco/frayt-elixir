defmodule FraytElixirWeb.Admin.MatchDetailsLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.AdminAlerts,
    name: "Match"

  use FraytElixirWeb.ModalEvents

  alias FraytElixir.{Drivers, Shipment, Matches}
  alias Shipment.{MatchWorkflow, Match, MatchStop, Address}
  alias FraytElixirWeb.Admin.MatchesView
  alias Phoenix.Socket.Broadcast
  alias Drivers.{Driver, DriverLocation}
  alias Ecto.Changeset
  alias FraytElixir.Helpers.NumberConversion
  alias FraytElixir.Notifications.DriverNotification
  import FraytElixirWeb.DisplayFunctions

  import FraytElixir.AtomizeKeys

  @forms ["pickup", "logistics", "stop_order", "payment"]
  @item_maps %{
    items: [
      :pieces,
      :weight,
      :description,
      :id,
      :width,
      :length,
      :height,
      :barcode_pickup_required,
      :barcode_delivery_required,
      :barcode,
      :declared_value
    ],
    fees: [:id, :type, :description, :amount, :driver_amount]
  }

  def mount(params, _session, socket) do
    %Match{driver: driver} = match = Shipment.get_match!(params["id"])

    %{coordinates: driver_location, inserted_at: driver_location_time} =
      Drivers.get_current_location(driver)
      |> convert_driver_location_values()

    if connected?(socket), do: subscribe_to_driver(driver)

    {:ok,
     assign(
       socket,
       close_forms()
       |> Map.merge(%{
         match: match,
         wide: false,
         match_changeset: nil,
         api_key: Application.get_env(:google_maps, :api_key),
         show_modal: false,
         driver_coordinates: driver_location,
         driver_coordinates_time: driver_location_time,
         show_buttons: false,
         stop_id: nil,
         title: nil,
         field: nil,
         total_payments: Shipment.get_match_payment_totals(match.id),
         time_zone: "UTC",
         driver_locations: driver_locations(match),
         state_transitions: state_transitions(match)
       })
     )}
  end

  defp state_transitions(match) do
    match_state_transitions =
      match.state_transitions |> FraytElixir.Repo.preload(:driver_location)

    match.match_stops
    |> FraytElixir.Repo.preload(state_transitions: [:driver_location])
    |> Enum.reduce(match_state_transitions, fn stop, acc ->
      acc ++ stop.state_transitions
    end)
  end

  defp driver_locations(match) do
    Drivers.get_locations_for_match(match)
    |> Enum.map(&(convert_driver_location_values(&1) |> Map.put(:id, &1.id)))
  end

  defp convert_driver_location_values(%DriverLocation{} = location),
    do:
      Map.from_struct(location)
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        case k do
          :inserted_at ->
            Map.put(acc, k, v)

          :geo_location ->
            Map.put(acc, :coordinates, %{
              latitude: elem(v.coordinates, 1),
              longitude: elem(v.coordinates, 0)
            })

          _ ->
            acc
        end
      end)

  defp convert_driver_location_values(_), do: %{coordinates: nil, inserted_at: nil}

  def handle_event("duplicate_match", _event, socket) do
    admin = socket.assigns.current_user.admin

    case Matches.duplicate_match(socket.assigns.match, %{admin: admin}, :inactive) do
      {:ok, match} ->
        path = Routes.match_details_path(socket, :add, match.id)
        {:noreply, redirect(socket, to: path)}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event("remove_driver", _event, %{assigns: %{match: match}} = socket) do
    current_driver = match.driver

    case Drivers.create_driver_removal(%{match_id: match.id, driver_id: current_driver.id}) do
      {:ok, _} ->
        match = transition_state(match, :assigning_driver)
        {:ok, _} = DriverNotification.send_removed_from_match_notification(current_driver, match)

        FraytElixirWeb.Endpoint.unsubscribe("driver_locations:#{current_driver.id}")

        send_alert(:info, "Driver removed successfully")

        {:noreply,
         assign(socket,
           match: match,
           state: match.state,
           transitions: match.state_transitions,
           driver_coordinates: nil,
           driver_locations: [],
           state_transitions: []
         )}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event("mark_as_" <> desired_state, _event, %{assigns: %{match: match}} = socket) do
    desired_state = String.to_atom(desired_state)

    match = transition_state(match, desired_state)

    send_alert(:info, "Match transitioned successfully")

    {:noreply, assign(socket, %{match: match})}
  end

  def handle_event("mark_stop_as:" <> desired_state, %{"stop-id" => stop_id}, socket) do
    case socket.assigns.match do
      %Match{state: :picked_up} = match ->
        desired_state = String.to_atom(desired_state)

        stop = match |> get_match_stop(stop_id) |> transition_state(desired_state)

        send_alert(:info, "Stop transitioned successfully")

        {:noreply, assign(socket, %{match: Shipment.get_match(stop.match_id)})}

      _ ->
        send_alert(:danger, "Unable to transition Stop: Match has already been completed")
        {:noreply, socket}
    end
  end

  def handle_event("open_notes", _event, socket) do
    {:noreply, assign(socket, :show_buttons, true)}
  end

  def handle_event("close_notes", _event, socket) do
    {:noreply, assign(socket, %{show_buttons: false})}
  end

  def handle_event("save_notes", %{"match-notes" => notes}, socket) do
    case Matches.update_match(socket.assigns.match, %{admin_notes: notes}) do
      {:ok, match} ->
        send_alert(:info, "Notes updated successfully")

        {:noreply, assign(socket, %{match: match, show_buttons: false})}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event("edit_" <> action, _, socket)
      when action in @forms do
    changeset = Match.changeset(socket.assigns.match, %{})

    {:noreply, assign(socket, edit_form(changeset, String.to_atom("edit_" <> action)))}
  end

  def handle_event("change_" <> action, %{"match" => attrs}, %{assigns: %{match: match}} = socket)
      when action in @forms do
    changeset =
      match
      |> Match.changeset(convert_match_attrs(attrs))
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, match_changeset: changeset)}
  end

  def handle_event("update_payment", %{"match" => attrs}, %{assigns: %{match: match}} = socket) do
    attrs = convert_match_attrs(attrs)

    case Matches.update_match_price(match, attrs) do
      {:ok, match} ->
        send_alert(:info, "Pricing updated successfully")

        {:noreply,
         assign(
           socket,
           update_form(match, total_payments: Shipment.get_match_payment_totals(match.id))
         )}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event(
        "update_" <> action,
        %{"match" => attrs},
        %{assigns: %{match: match, current_user: user}} = socket
      )
      when action in @forms do
    case Matches.update_match(match, convert_match_attrs(attrs), user.admin) do
      {:ok, match} ->
        send_alert(:info, title_case(action) <> " updated successfully")

        {:noreply,
         assign(
           socket,
           update_form(match, total_payments: Shipment.get_match_payment_totals(match.id))
         )}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event(
        "move_stop:" <> stop_id,
        %{"index" => index},
        %{assigns: %{match_changeset: changeset, match: match}} = socket
      ) do
    index = String.to_integer(index)

    stops = Changeset.get_field(changeset, :match_stops)

    attrs = move_stop_attrs(stops, stop_id, index)

    changeset =
      match
      |> Match.changeset(attrs)
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, match_changeset: changeset)}
  end

  def handle_event("add_stop", _, socket) do
    changeset = MatchStop.changeset(%MatchStop{destination_address: %Address{}, items: []}, %{})

    {:noreply, assign(socket, edit_form(changeset, :edit_stop, "new"))}
  end

  def handle_event("edit_stop:" <> stop_id, _, socket) do
    changeset = MatchStop.changeset(get_match_stop(socket.assigns.match, stop_id), %{})

    {:noreply, assign(socket, edit_form(changeset, :edit_stop, stop_id))}
  end

  def handle_event(
        "change_stop",
        %{"match_stop" => attrs},
        %{assigns: %{match_changeset: %Changeset{data: stop}}} = socket
      ) do
    changeset =
      stop
      |> MatchStop.changeset(convert_stop_attrs(attrs))
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, match_changeset: changeset)}
  end

  def handle_event(
        "update_stop:" <> stop_id,
        %{"match_stop" => attrs},
        %{assigns: %{match: match}} = socket
      ) do
    attrs = convert_stop_attrs(attrs)

    case Matches.update_or_insert_stop(match, stop_id, attrs) do
      {:ok, match} ->
        send_alert(:info, "Stop updated successfully")

        {:noreply,
         assign(
           socket,
           update_form(match, total_payments: Shipment.get_match_payment_totals(match.id))
         )}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event("delete_stop:" <> stop_id, _params, %{assigns: %{match: match}} = socket) do
    case Matches.delete_stop(match, stop_id) do
      {:ok, match} ->
        send_alert(:info, "Stop deleted successfully")

        {:noreply,
         assign(
           socket,
           update_form(match, total_payments: Shipment.get_match_payment_totals(match.id))
         )}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event(
        "repeater_add_" <> key,
        _,
        %{assigns: %{match_changeset: changeset}} = socket
      ) do
    key = String.to_existing_atom(key)

    changeset =
      changeset
      |> Changeset.change(%{key => add_items_attrs(changeset, key)})

    {:noreply, assign(socket, match_changeset: changeset)}
  end

  def handle_event(
        "repeater_remove_" <> key,
        %{"index" => index},
        %{assigns: %{match_changeset: changeset}} = socket
      ) do
    key = String.to_existing_atom(key)

    changeset =
      changeset
      |> Changeset.change(%{
        key => remove_items_attrs(changeset, key, String.to_integer(index))
      })

    {:noreply, assign(socket, match_changeset: changeset)}
  end

  def handle_event("edit_payment", _event, socket) do
    match_changeset = Match.changeset(socket.assigns.match, %{})

    {:noreply, assign(socket, edit_form(match_changeset, :edit_payment))}
  end

  def handle_event("cancel_edit", _event, socket) do
    {:noreply, assign(socket, close_forms())}
  end

  def handle_event(
        "authorize_match",
        _params,
        socket
      ) do
    case Matches.update_and_authorize_match(socket.assigns.match) do
      {:ok, match} ->
        send_alert(:info, "Match authorized successfully")
        {:noreply, assign(socket, :match, match)}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_event("optimize_stops", _, %{assigns: %{match: match}} = socket) do
    case Matches.update_match(match, %{optimize: true}) do
      {:ok, match} ->
        send_alert(:info, "Match Stops optimized successfully")

        {:noreply, assign(socket, match: match)}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_info({:match_sla_updated, sla}, socket) do
    match = socket.assigns.match
    slas = Enum.filter(match.slas, &(&1.id != sla.id))
    match = Map.put(match, :slas, [sla | slas])

    send(self(), {:send_alert, :info, "Time updated successfully!"})

    {:noreply, assign(socket, :match, match)}
  end

  def handle_info({:assign_admin_to_match, match, admin_id}, socket) do
    attrs = %{network_operator_id: admin_id}

    case Matches.update_match(match, attrs) do
      {:ok, match} ->
        send_alert(:info, "Network operator updated")
        {:noreply, assign(socket, :match, match)}

      error ->
        send_update_error_alert(error)
        {:noreply, socket}
    end
  end

  def handle_info({:updated_match, match}, socket),
    do: handle_info({:updated_match, match, "Match updated successfully"}, socket)

  def handle_info(
        {:updated_match,
         %Match{
           driver: driver
         } = match, message},
        socket
      ) do
    current_location =
      update_driver_coordinates(
        socket.assigns.match.driver,
        driver,
        socket.assigns.driver_coordinates
      )

    send_alert(:info, message)

    {:noreply,
     assign(socket,
       match: match,
       state: match.state,
       transitions: match.state_transitions,
       show_modal: false,
       driver_coordinates: current_location,
       total_payments: Shipment.get_match_payment_totals(match.id)
     )}
  end

  def handle_info({:match_canceled, match}, socket) do
    if socket.assigns.match.driver do
      FraytElixirWeb.Endpoint.unsubscribe("driverlocations:#{socket.assigns.match.driver.id}")
    end

    send_alert(:info, "Match canceled successfully")

    {:noreply,
     assign(socket, %{
       match: match,
       state: match.state,
       state_transitions: match.state_transitions,
       show_modal: false,
       driver_coordinates: nil,
       total_payments: Shipment.get_match_payment_totals(match.id)
     })}
  end

  def handle_info({:match_renewed, match}, socket) do
    if socket.assigns.match.driver do
      FraytElixirWeb.Endpoint.subscribe("driverlocations:#{socket.assigns.match.driver.id}")
    end

    send_alert(:info, "Match renewed successfully")

    {:noreply,
     assign(socket, %{
       match: match,
       state: match.state,
       state_transitions: match.state_transitions,
       show_modal: false
     })}
  end

  def handle_info(
        %Broadcast{
          topic: _,
          event: "driver_location",
          payload: %DriverLocation{
            inserted_at: inserted_at,
            geo_location: %Geo.Point{coordinates: {lng, lat}}
          }
        },
        socket
      ) do
    match = socket.assigns.match

    {:noreply,
     assign(socket, %{
       driver_coordinates: %{latitude: lat, longitude: lng},
       driver_coordinates_time: inserted_at,
       driver_locations: driver_locations(match),
       state_transitions: state_transitions(match)
     })}
  end

  defp move_stop_attrs(stops, target_id, to_index) do
    orig_index =
      stops
      |> Enum.find(&(&1.id == target_id))
      |> Map.get(:index)

    stops_attrs =
      stops
      |> Enum.map(fn stop ->
        new_index = get_reordered_stop_index(stop, target_id, orig_index, to_index)

        %{
          id: stop.id,
          index: new_index
        }
      end)
      |> Enum.sort_by(& &1.index)

    %{
      match_stops: stops_attrs
    }
  end

  defp get_reordered_stop_index(%MatchStop{id: stop_id}, target_id, _orig_idx, to_idx)
       when target_id == stop_id,
       do: to_idx

  defp get_reordered_stop_index(stop, _target_id, orig_idx, to_idx) do
    case stop.index do
      i when i <= to_idx and i >= orig_idx and orig_idx < to_idx -> i - 1
      i when i >= to_idx and i <= orig_idx and orig_idx > to_idx -> i + 1
      i -> i
    end
  end

  def subscribe_to_driver(nil), do: nil

  def subscribe_to_driver(driver) do
    FraytElixirWeb.Endpoint.subscribe("driver_locations:#{driver.id}")

    case Drivers.get_current_location(driver.id) do
      %DriverLocation{geo_location: %Geo.Point{coordinates: {longitude, latitude}}} ->
        %{latitude: latitude, longitude: longitude}

      _ ->
        nil
    end
  end

  def update_driver_coordinates(nil, nil, _old_coordinates), do: nil

  def update_driver_coordinates(%Driver{id: driver_id}, nil, _old_coordinates) do
    FraytElixirWeb.Endpoint.unsubscribe("driver_locations:#{driver_id}")
    nil
  end

  def update_driver_coordinates(nil, new_driver, _old_coordinates),
    do: subscribe_to_driver(new_driver)

  def update_driver_coordinates(
        %Driver{id: old_driver_id},
        %Driver{id: new_driver_id},
        old_coordinates
      )
      when old_driver_id == new_driver_id,
      do: old_coordinates

  def update_driver_coordinates(%Driver{id: old_driver_id}, new_driver, _old_coordinates) do
    FraytElixirWeb.Endpoint.unsubscribe("driver_locations:#{old_driver_id}")
    subscribe_to_driver(new_driver)
  end

  def render(assigns) do
    MatchesView.render("match_details.html", assigns)
  end

  defp close_forms,
    do: %{
      edit_logistics: false,
      edit_stop_order: false,
      edit_payment: false,
      edit_pickup: false,
      edit_stop: nil
    }

  defp update_form(match, assign),
    do:
      close_forms()
      |> Map.merge(%{match: match, match_changeset: nil})
      |> Map.merge(Enum.into(assign, %{}))

  defp edit_form(match_changeset, form, value \\ true),
    do:
      close_forms()
      |> Map.put(form, value)
      |> Map.put(:match_changeset, match_changeset)

  defp get_match_stop(%Match{match_stops: stops}, stop_id),
    do: Enum.find(stops, fn stop -> stop.id == stop_id end)

  defp transition_state(%MatchStop{state: state} = stop, to_state),
    do:
      transition_state(
        stop,
        to_state,
        match_stop_state_as_number(state) <= match_stop_state_as_number(to_state)
      )

  defp transition_state(%Match{state: state} = match, to_state),
    do: transition_state(match, to_state, stage_as_number(state) <= stage_as_number(to_state))

  defp transition_state(record, to_state, true),
    do: MatchWorkflow.force_transition_state(record, to_state)

  defp transition_state(record, to_state, false),
    do: MatchWorkflow.force_backwards_transition_state(record, to_state)

  defp to_float(float) do
    case Float.parse(float) do
      {float, _} -> float
      _ -> nil
    end
  end

  defp convert_match_attrs(%{"match_stops" => stops} = attrs),
    do:
      attrs
      |> Map.put(:stops, Enum.map(stops, fn {_, stop} -> stop end))
      |> Map.delete("match_stops")
      |> convert_match_attrs()

  defp convert_match_attrs(%{"fees" => fees} = attrs) do
    attrs
    |> Map.put(
      :fees,
      Enum.map(fees, fn {_index, %{"amount" => amount, "driver_amount" => driver_amount} = fee} ->
        %{
          fee
          | "amount" => NumberConversion.dollars_to_cents(amount),
            "driver_amount" => NumberConversion.dollars_to_cents(driver_amount)
        }
      end)
    )
    |> Map.delete("fees")
    |> convert_match_attrs()
  end

  defp convert_match_attrs(%{"manual_price" => manual_price} = attrs),
    do:
      attrs
      |> Map.put(:manual_price, manual_price == "true")
      |> Map.delete("manual_price")
      |> convert_match_attrs()

  defp convert_match_attrs(attrs), do: atomize_keys(attrs)

  defp convert_stop_attrs(attrs) do
    items =
      attrs
      |> Map.get("items", [])
      |> Enum.map(fn {_index, item} ->
        volume =
          case Map.get(item, "volume", "") |> to_float() do
            volume when is_number(volume) -> ceil(volume * 1728)
            volume -> volume
          end

        declared_value =
          Map.get(item, "declared_value", 0)
          |> NumberConversion.dollars_to_cents()

        item
        |> Map.put("volume", volume)
        |> Map.put("declared_value", declared_value)
      end)

    attrs |> Map.put("items", items) |> atomize_keys()
  end

  defp add_items_attrs(changeset, key),
    do:
      changeset
      |> Changeset.get_field(key, [])
      |> Enum.map(&convert_item_attrs(&1, key))
      |> Enum.concat([%{}])

  defp remove_items_attrs(changeset, key, index) do
    changeset
    |> Changeset.get_field(key, [])
    |> Enum.map(&convert_item_attrs(&1, key))
    |> Enum.with_index()
    |> Enum.reject(fn {_item, i} -> i === index end)
    |> Enum.map(fn {item, _} -> item end)
  end

  defp convert_item_attrs(attrs, key), do: Map.take(attrs, @item_maps[key])

  defp send_update_error_alert(error),
    do: send_alert(:danger, humanize_update_errors(error, "Match"))
end
