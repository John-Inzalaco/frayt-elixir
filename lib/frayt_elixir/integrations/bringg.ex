defmodule FraytElixir.Integrations.Bringg do
  alias FraytElixir.{Shipment, Matches, Repo, Utils}
  alias FraytElixir.Shipment.{Address, Match, MatchStop, MatchStateTransition}
  alias FraytElixir.Shipment.MatchStopStateTransition
  alias FraytElixir.Notifications.{DriverNotification, Slack}
  alias Ecto.Multi
  alias FraytElixir.GeocodedAddressHelper
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Accounts.User
  alias FraytElixirWeb.DisplayFunctions

  @bringg_reasons %{
    1045 => "Party City Canceled",
    1046 => "Party City Canceled"
  }

  def bringg_client, do: Application.get_env(:frayt_elixir, :bringg_client)

  def bringg_api_url, do: Application.get_env(:frayt_elixir, :bringg_api_url)

  def put_auth_header(_client_id, config) do
    [{"Authorization", "Bearer " <> bringg_client().get_token(config)}]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :assigning_driver
        },
        _
      ) do
    []
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :picked_up
        } = match,
        %MatchStopStateTransition{to: :en_route}
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {
        bringg_api_url() <> "/open_fleet_services/update_driver_location",
        %{
          user_external_id: match.driver.id,
          lat: lat,
          lng: lng
        }
      }
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :picked_up,
          identifier: bringg_match_id
        } = match,
        %MatchStopStateTransition{to: :arrived, match_stop: match_stop}
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {bringg_api_url() <> "/open_fleet_services/checkin",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match_stop, :arrived),
         pickup_dropoff_option: "dropoff"
       }
       |> add_coords_to_params({lat, lng})}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :picked_up
        },
        %MatchStopStateTransition{to: :signed}
      ) do
    []
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :picked_up,
          identifier: bringg_match_id
        } = match,
        %MatchStopStateTransition{to: :delivered, match_stop: match_stop}
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {bringg_api_url() <> "/open_fleet_services/create_note",
       %{
         task_id: bringg_match_id,
         way_point_position: 2,
         type: "TaskPhoto",
         image: fetch_and_encode_image(match_stop.id, match_stop.destination_photo)
       }},
      {bringg_api_url() <> "/open_fleet_services/checkout",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match_stop, :delivered)
       }
       |> add_coords_to_params({lat, lng})}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :accepted,
          driver: %Driver{
            id: driver_id,
            first_name: first_name,
            last_name: last_name,
            user: %User{email: email}
          },
          identifier: bringg_match_id
        } = match,
        _from_state
      ) do
    [
      {bringg_api_url() <> "/open_fleet_services/assign_driver",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match, :accepted),
         user: %{
           external_id: driver_id,
           name: "#{first_name} #{last_name}",
           email: email
         }
       }}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :en_route_to_pickup,
          identifier: bringg_match_id
        } = match,
        _from_state
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {bringg_api_url() <> "/open_fleet_services/start_task",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match, :en_route_to_pickup)
       }
       |> add_coords_to_params({lat, lng})}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :arrived_at_pickup,
          identifier: bringg_match_id
        } = match,
        _
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {bringg_api_url() <> "/open_fleet_services/checkin",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match, :arrived_at_pickup),
         pickup_dropoff_option: "pickup"
       }
       |> add_coords_to_params({lat, lng})}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          id: match_id,
          state: :picked_up,
          origin_photo: origin_photo,
          bill_of_lading_photo: bill_of_lading_photo,
          identifier: bringg_match_id
        } = match,
        _
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {bringg_api_url() <> "/open_fleet_services/create_note",
       %{
         task_id: bringg_match_id,
         way_point_position: 1,
         type: "TaskPhoto",
         image: fetch_and_encode_image(match_id, origin_photo)
       }},
      {bringg_api_url() <> "/open_fleet_services/create_note",
       %{
         task_id: bringg_match_id,
         way_point_position: 1,
         type: "TaskPhoto",
         image: fetch_and_encode_image(match_id, bill_of_lading_photo)
       }},
      {bringg_api_url() <> "/open_fleet_services/checkout",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match, :picked_up)
       }
       |> add_coords_to_params({lat, lng})}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: :completed,
          identifier: bringg_match_id
        } = match,
        _from_state
      ) do
    %{geo_location: %Geo.Point{coordinates: {lng, lat}}} = match.driver.current_location

    [
      {bringg_api_url() <> "/open_fleet_services/end_task",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.get_reported_time(match, :completed)
       }
       |> add_coords_to_params({lat, lng})}
    ]
  end

  def build_webhook_request(
        _company,
        %Match{
          state: state,
          identifier: bringg_match_id
        } = match,
        _
      )
      when state in [:canceled, :admin_canceled, :driver_canceled] do
    %MatchStateTransition{notes: reason, inserted_at: inserted_at} =
      Shipment.most_recent_transition(match, state)

    [
      {bringg_api_url() <> "/open_fleet_services/cancel_delivery",
       %{
         task_id: bringg_match_id,
         reported_time: DisplayFunctions.date_time_to_unix(inserted_at),
         reason_id: 0,
         reason: reason
       }}
    ]
  end

  defp add_coords_to_params(params, {lat, lng}),
    do: Map.merge(params, %{lat: lat, lng: lng})

  def update_match(%Match{state: state} = match, match_attrs)
      when state in [:inactive, :pending, :scheduled, :assigning_driver] do
    Slack.send_match_message(
      match,
      "Changes to be made: " <> create_changes_message(match_attrs),
      :alert
    )

    cast_updates(match, match_attrs)
  end

  def update_match(%Match{state: :accepted, driver: driver} = match, match_attrs) do
    Slack.send_match_message(
      match,
      "Changes to be made: " <> create_changes_message(match_attrs),
      :warning
    )

    DriverNotification.send_idle_driver_warning(driver, match)

    cast_updates(match, match_attrs)
  end

  def update_match(%Match{state: state} = match, match_attrs)
      when state in [
             :en_route_to_pickup,
             :arrived_at_pickup,
             :picked_up,
             :completed,
             :charged,
             :admin_canceled,
             :driver_canceled,
             :canceled
           ] do
    Slack.send_match_message(
      match,
      "Listing changes attempted: " <> create_changes_message(match_attrs),
      :danger
    )

    {:error, match}
  end

  defp create_changes_message(%{} = attrs) do
    attrs
    |> Map.to_list()
    |> reduce_to_readable(" ")
  end

  defp reduce_to_readable([head | [] = _tail], acc) do
    acc <> create_change_field_message(head)
  end

  defp reduce_to_readable([head | tail], acc) do
    acc <> create_change_field_message(head) <> ", " <> reduce_to_readable(tail, acc)
  end

  defp create_change_field_message({parent_key, {v0, v1}}) do
    "(#{parent_key} - #{v0} and #{v1})"
  end

  defp create_change_field_message({parent_key, %{} = value}) do
    value
    |> Map.to_list()
    |> reduce_to_readable(" ")
    |> (&"(#{parent_key} - #{&1})").()
  end

  defp create_change_field_message({k, v}) do
    "#{k}: #{v}"
  end

  defp cast_updates(match, match_attrs) do
    match = match |> Repo.preload(match_stops: [:items])

    Multi.new()
    |> Multi.update(:notes, notes_changeset(match, match_attrs))
    |> Multi.update(:schedule, schedule_changeset(match, match_attrs))
    |> Multi.update(:inventory, fn %{schedule: match} ->
      inventory_changeset(match, match_attrs)
    end)
    |> Multi.update(:recipient, recipient_changeset(match, match_attrs))
    |> Multi.update(:origin_address, origin_address_changeset(match, match_attrs))
    |> Multi.update(
      :destination_address,
      destination_address_changeset(match, match_attrs)
    )
    |> format_addresses()
    |> Multi.run(:orig_match, fn _repo, _changes ->
      {:ok, match}
    end)
    |> Multi.run(:match, fn _repo,
                            %{
                              inventory: match
                            } ->
      {:ok, Shipment.get_match(match.id)}
    end)
    |> Matches.match_changes(%{autoselect_vehicle_class: true, vehicle_class: nil})
    |> Repo.transaction()
  end

  defp format_addresses(multi) do
    multi
    |> Multi.merge(fn %{
                        origin_address: origin_address,
                        destination_address: destination_address
                      } ->
      Multi.new()
      |> Multi.update(
        :format_origin_address,
        Address.format_address_changeset(origin_address)
      )
      |> Multi.update(
        :format_destination_address,
        Address.format_address_changeset(destination_address)
      )
    end)
  end

  def merge_multi_update(multi, changeset_fn) do
    multi
    |> Multi.merge(fn previous_results ->
      {key, changeset} = changeset_fn.(previous_results)
      Multi.new() |> Multi.update(key, changeset)
    end)
  end

  def sanitize_match_params(%{"way_points" => way_points} = match) when is_list(way_points) do
    %{
      match
      | "way_points" => way_points |> Enum.map(&sanitize_way_point_params/1)
    }
    |> Map.put("tip", floor((Map.get(match, "tip") || 0) * 100))
  end

  def sanitize_match_params(match), do: match

  defp sanitize_way_point_params(%{"inventory" => inventory} = way_point)
       when is_list(inventory) do
    %{
      way_point
      | "inventory" => inventory |> Enum.map(&sanitize_item_params/1)
    }
    |> Map.put("scheduled_at", get_waypoint_scheduled_at(way_point))
  end

  defp sanitize_way_point_params(way_point), do: way_point

  defp sanitize_item_params(
         %{"width" => width, "length" => length, "height" => height, "weight" => weight} = item
       ),
       do: %{
         item
         | "width" => ceil(width),
           "length" => ceil(length),
           "height" => ceil(height),
           "weight" => ceil(weight)
       }

  defp sanitize_item_params(item), do: item

  defp get_waypoint_scheduled_at(%{"scheduled_at" => scheduled_at})
       when not is_nil(scheduled_at) do
    case NaiveDateTime.from_iso8601(scheduled_at) do
      {:ok, datetime} -> datetime
      {:error, _} -> scheduled_at
    end
  end

  defp get_waypoint_scheduled_at(%{
         "no_earlier_than" => no_earlier_than,
         "no_later_than" => no_later_than
       }) do
    with {:ok, earliest} <- NaiveDateTime.from_iso8601(no_earlier_than),
         {:ok, latest} <- NaiveDateTime.from_iso8601(no_later_than) do
      latest
      |> NaiveDateTime.add(floor(NaiveDateTime.diff(earliest, latest) / 2))
    else
      _ -> nil
    end
  end

  defp get_waypoint_scheduled_at(_), do: nil

  defp origin_address_changeset(
         %Match{
           origin_address: origin_address
         },
         %{way_point: %{position: 1} = way_point}
       ) do
    Address.changeset(origin_address, way_point |> extract_address())
  end

  defp origin_address_changeset(
         %Match{
           origin_address: origin_address
         },
         _
       ) do
    no_changeset(origin_address)
  end

  defp destination_address_changeset(
         %Match{
           match_stops: [%MatchStop{destination_address: destination_address}]
         },
         %{way_point: %{position: 2} = way_point}
       ) do
    Address.changeset(destination_address, way_point |> extract_address())
  end

  defp destination_address_changeset(
         %Match{
           match_stops: [%MatchStop{destination_address: destination_address}]
         },
         _
       ) do
    no_changeset(destination_address)
  end

  defp schedule_changeset(%Match{pickup_at: match_pickup_at} = match, %{
         way_point: %{position: position, scheduled_at: scheduled_at}
       }) do
    key =
      case position do
        1 -> :pickup_at
        2 -> :dropoff_at
      end

    Match.changeset(match, %{key => scheduled_at, scheduled: position == 1 || !!match_pickup_at})
  end

  defp schedule_changeset(match, _), do: no_changeset(match)

  defp recipient_changeset(
         %Match{match_stops: [match_stop]},
         %{way_point: waypoint_params}
       ) do
    MatchStop.changeset(
      match_stop,
      %{
        recipient:
          waypoint_params
          |> Utils.map_keys(%{name: :name, email: :email, phone: :phone_number})
      }
    )
  end

  defp recipient_changeset(%Match{match_stops: [match_stop]}, _),
    do: no_changeset(match_stop)

  defp inventory_changeset(m, %{task_inventory: %{id: id} = inventory}) when is_number(id),
    do: inventory_changeset(m, %{task_inventory: inventory |> Map.put(:id, to_string(id))})

  defp inventory_changeset(
         %Match{
           match_stops: [%MatchStop{items: items, id: match_stop_id}]
         } = match,
         %{task_inventory: %{original_quantity: quantity, id: external_id}}
       ) do
    items =
      Enum.map(items, fn item ->
        case item do
          item = %{external_id: ^external_id} ->
            item
            |> Map.take([:id, :width, :length, :height, :weight, :volume])
            |> Map.put(:pieces, quantity)

          item ->
            item |> Map.take([:id])
        end
      end)
      |> Enum.filter(& &1)

    match
    |> Match.changeset(%{
      match_stops: [
        %{
          id: match_stop_id,
          items: items
        }
      ]
    })
    |> Ecto.Changeset.cast_assoc(:match_stops)
  end

  defp inventory_changeset(match, _),
    do: no_changeset(match)

  defp notes_changeset(
         %Match{
           admin_notes: admin_notes,
           pickup_notes: pickup_notes,
           match_stops: [
             %MatchStop{identifier: match_stop_identifier, delivery_notes: delivery_notes} = stop
           ]
         } = match,
         %{task_note: %{note: note} = task_note}
       ) do
    {key, original_value, joiner} =
      case to_string(task_note[:way_point_id]) do
        "" -> {:admin_notes, admin_notes, "\n"}
        ^match_stop_identifier -> {:delivery_notes, delivery_notes, "; "}
        _ -> {:pickup_notes, pickup_notes, "; "}
      end

    note =
      if original_value do
        Enum.join([original_value, note], joiner)
      else
        note
      end

    case key do
      :delivery_notes ->
        MatchStop.changeset(stop, %{delivery_notes: note})

      key ->
        Match.changeset(match, %{key => note})
    end
  end

  defp notes_changeset(match, _), do: no_changeset(match)

  def cancel_match(match, attrs) do
    reason = Map.get(attrs, :reason_id) |> parse_reason_id(Map.get(attrs, :reason, nil))

    with %Match{state: :canceled} = updated_match <-
           Shipment.shipper_cancel_match(
             match,
             "Canceled by Bringg#{if reason, do: "\: #{reason}"}"
           ) do
      {:ok, updated_match}
    end
  end

  defp parse_reason_id(_reason_id, reason) when not is_nil(reason), do: reason
  defp parse_reason_id(reason_id, _), do: Map.get(@bringg_reasons, reason_id)

  def convert_params(
        %{
          id: identifier,
          way_points: way_points,
          customer: customer
        } = params
      ) do
    origin_waypoint = way_points |> find_waypoint("pickup")
    destination_waypoint = way_points |> find_waypoint("dropoff")

    extract_inventory_params(origin_waypoint)
    |> extract_customer(customer)
    |> Map.merge(%{
      pickup_notes: parse_notes(origin_waypoint[:notes]),
      delivery_notes: parse_notes(destination_waypoint[:notes]),
      admin_notes: parse_notes(params[:notes], "\n"),
      identifier: to_string(identifier),
      po: to_string(Map.get(params, :external_id)),
      pickup_at: origin_waypoint[:scheduled_at],
      dropoff_at: destination_waypoint[:scheduled_at],
      match_stop_identifier: to_string(destination_waypoint[:id]),
      scheduled: not is_nil(origin_waypoint[:scheduled_at]),
      origin_address: build_address(origin_waypoint),
      destination_address: build_address(destination_waypoint),
      tip: params[:tip] || 0,
      contract: nil,
      service_level: 1,
      autoselect_vehicle_class: true
    })
  end

  defp find_waypoint(waypoints, pickup_dropoff),
    do:
      waypoints
      |> Enum.find(fn %{pickup_dropoff_option: pickup_dropoff_option} ->
        pickup_dropoff_option == pickup_dropoff
      end)

  defp extract_address(
         %{
           lat: lat,
           lng: lng
         } = attrs
       ) do
    Utils.map_keys(attrs, %{
      address: :address,
      address_second_line: :address2,
      city: :city,
      state: :state,
      zipcode: :zip
    })
    |> Map.put(:geo_location, %Geo.Point{coordinates: {lng, lat}})
  end

  defp extract_address(attrs) do
    Utils.map_keys(attrs, %{
      address: :address,
      address_second_line: :address2,
      city: :city,
      state: :state,
      zipcode: :zip
    })
  end

  defp build_address(%{
         address: address,
         address_second_line: address2,
         city: city,
         state: state,
         zipcode: zip,
         lat: lat,
         lng: lng
       })
       when not is_nil(lat) and not is_nil(lng),
       do: %{
         formatted_address:
           "#{address}#{if address2, do: " #{address2}"}, #{city}, #{state} #{zip}",
         address: address,
         address2: address2,
         city: city,
         state: state,
         zip: zip,
         geo_location: %Geo.Point{coordinates: {lng, lat}}
       }

  defp build_address(
         %{
           address: address,
           address_second_line: address2,
           city: city,
           state: state,
           zipcode: zip
         } = params
       ) do
    case "#{address}#{if address2, do: " #{address2}"}, #{city}, #{state} #{zip}"
         |> GeocodedAddressHelper.get_geocoded_address() do
      {:ok,
       %{"results" => [%{"geometry" => %{"location" => %{"lat" => lat, "lng" => lng}}} | _tl]}} ->
        build_address(params |> Map.put(:lat, lat) |> Map.put(:lng, lng))

      _ ->
        nil
    end
  end

  defp parse_notes(notes, joiner \\ "; ")
  defp parse_notes(nil, _joiner), do: nil

  defp parse_notes(notes, joiner) do
    notes
    |> Enum.map_join(joiner, & &1.note)
  end

  defp extract_inventory_params(%{
         inventory: inventory
       }),
       do: %{
         items: extract_items(inventory)
       }

  defp extract_items(inventory, items \\ [])

  defp extract_items([item | inventory], items),
    do: extract_items(inventory, items ++ [extract_item(item)])

  defp extract_items([], items), do: items

  defp extract_item(%{id: id} = item) when is_number(id),
    do: extract_item(item |> Map.put(:id, to_string(id)))

  defp extract_item(
         %{original_quantity: pieces, id: external_id, name: description, price: price} = item
       ),
       do:
         item
         |> Map.take([:width, :height, :length, :weight])
         |> Map.put(:pieces, pieces)
         |> Map.put(:external_id, external_id)
         |> Map.put(:description, description)
         |> Map.put(:declared_value, price)

  defp extract_customer(attrs, customer),
    do:
      %{
        recipient_email: customer[:email],
        recipient_phone: customer[:phone],
        recipient_name: customer[:name]
      }
      |> Map.merge(attrs)

  defp no_changeset(thing), do: Ecto.Changeset.change(thing, %{})

  defp fetch_and_encode_image(_, photo) when is_nil(photo), do: nil

  defp fetch_and_encode_image(match_stop_id, signature_photo) do
    case DisplayFunctions.get_photo_url(match_stop_id, signature_photo)
         |> HTTPoison.get() do
      {:ok, %{body: binary}} -> "data:application/binary;base64,#{Base.encode64(binary)}"
      _ -> nil
    end
  end
end
