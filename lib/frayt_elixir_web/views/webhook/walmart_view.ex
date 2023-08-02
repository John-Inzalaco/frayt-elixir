defmodule FraytElixirWeb.Webhook.WalmartView do
  use FraytElixirWeb, :view
  alias FraytElixir.Shipment.MatchState
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Photo
  alias FraytElixir.Integrations.Walmart

  import FraytElixirWeb.DisplayFunctions, only: [humanize_errors: 1]

  @canceled_states MatchState.canceled_range() ++ [:driver_canceled]
  @return_states [:undeliverable, :returned]

  def render("cancel_response.json", %{match_state_transition: mst}) do
    %{
      cancelReason: mst.code,
      comment: mst.notes,
      cancelledAt: mst.updated_at
    }
  end

  def render("match.json", %{match: match}) do
    %{
      id: match.id,
      externalOrderId: match.identifier,
      externalDeliveryId: match.meta["external_delivery_id"],
      estimatedPickupTime: get_eta(match),
      estimatedDeliveryTime: get_eta(match.match_stops),
      deliveryWindowStartTime: match.dropoff_at,
      deliveryWindowEndTime: nil,
      pickupWindowStartTime: match.pickup_at,
      pickupWindowEndTime: nil,
      externalStoreId: match.meta["external_store_id"],
      fee: match.amount_charged,
      currency: "USD",
      tip: get_driver_tip(match.fees)
    }
  end

  def render("match_webhook.json", %{match: match}) do
    %{match_stops: [stop | _]} = match

    %{
      "id" => match.id,
      "external_order_id" => match.identifier,
      "external_store_id" => match.meta["external_store_id"],
      "status" => get_order_state(match),
      "timestamp" => DateTime.utc_now(),
      "batch_id" => nil,
      "pickup_parking_slot" => get_parking_spot(match, :arrived_at_pickup),
      "return_parking_slot" => get_parking_spot(match, :arrived_at_return),
      "courier" => build_courier_info(match),
      "estimated_pickup_time" => get_eta(match),
      "estimated_delivery_time" => get_eta(match.match_stops),
      "estimated_return_time" => nil,
      "actual_pickup_time" => Shipment.match_transitioned_at(match, :picked_up),
      "actual_delivery_time" => Shipment.match_transitioned_at(stop, :delivered),
      "actual_return_time" => Shipment.match_transitioned_at(stop, :returned),
      "pickup_eta" => get_eta_duration(match, :en_route_to_pickup),
      "dropoff_eta" => get_eta_duration(stop, :en_route),
      "return_eta" => get_eta_duration(match, :en_route_to_return),
      "return_reason_code" => return_reason_code(match),
      "cancel_reason_code" => cancel_reason_code(match),
      "dropoff_verification" => %{
        "signature_image_url" => image_url(match.match_stops, :signature),
        "delivery_proof_image_url" => image_url(match.match_stops, :delivery)
      }
    }
    |> ProperCase.to_camel_case()
  end

  def render("show_match.json", %{match: match}) do
    match.meta
    |> Map.put("status", get_order_state(match))
    |> Map.put("courier", build_courier_info(match))
    |> Map.put("id", match.id)
    |> Map.put("external_order_id", match.identifier)
    |> Map.put("delivery_window_end_time", match.dropoff_at)
    |> Map.put("pickup_window_end_time", match.pickup_at)
    |> Map.put("estimated_pickup_time", get_eta(match))
    |> Map.put("estimated_delivery_time", get_eta(match.match_stops))
    |> Map.put("fee", match.amount_charged)
    |> Map.put("tip", get_driver_tip(match.fees))
    |> Map.put("pickup_parking_slot", get_parking_spot(match, :arrived_at_pickup))
    |> Map.put("return_parking_slot", get_parking_spot(match, :arrived_at_return))
    |> ProperCase.to_camel_case()
  end

  def render("updated_tip_resp.json", %{match: match}) do
    [first_stop | _] = match.match_stops

    %{
      "id" => match.id,
      "externalOrderId" => match.identifier,
      "tip" => first_stop.tip_price,
      "tipStatus" => "success"
    }
  end

  def render("error.json", reason) do
    %{
      success: false,
      error_message: reason
    }
  end

  def render("error_message.json", %{changeset: changeset, code: :walmart_error}) do
    %{
      status: "error",
      error: %{
        errorCode: Walmart.get_error_code(changeset),
        errorMessage: humanize_errors(changeset)
      }
    }
  end

  def render("error_message.json", %{changeset: changeset}),
    do: render("error_message.json", %{changeset: changeset, code: "invalid_attributes"})

  defp get_eta_duration(%{state: state, eta: %{arrive_at: arrive_at}}, target_state)
       when state == target_state do
    now = NaiveDateTime.utc_now()

    arrive_at
    |> NaiveDateTime.diff(now, :second)
    |> max(0)
  end

  defp get_eta_duration(_eta, _target_state), do: 0

  defp image_url([stop | _], type) do
    {photo, required?} = get_image_meta(stop, type)

    if required? do
      case Photo.get_url(stop.id, photo) do
        {:ok, photo_url} -> photo_url
        _ -> nil
      end
    end
  end

  defp get_image_meta(stop, :signature), do: {stop.signature_photo, stop.signature_required}

  defp get_image_meta(stop, :delivery),
    do: {stop.destination_photo, stop.destination_photo_required}

  defp return_reason_code(%Match{match_stops: [%{state: state} = stop | _]} = match)
       when state in @return_states do
    cancel_code = get_cancel_reason_code(match)

    with %{notes: notes} <- Shipment.find_transition(stop, [:undeliverable], :desc) do
      case notes do
        "I couldn't find the delivery location" ->
          "Can't Find Address"

        "I was unable to access the delivery location" ->
          "Can't Find Address"

        "Safety concern" ->
          "Unsafe Location"

        "Missing Item" ->
          "Lost or damaged goods"

        nil ->
          case cancel_code do
            "COLD_CHAIN_VIOLATION" -> "Exceeded Cold Chain"
            _ -> "Other issue (Admin action)"
          end

        notes ->
          "Other issue (#{notes})"
      end
    end
  end

  defp return_reason_code(_match), do: nil

  defp cancel_reason_code(%Match{state: state} = match) when state in @canceled_states,
    do: get_cancel_reason_code(match)

  defp cancel_reason_code(_match), do: nil

  defp get_cancel_reason_code(match) do
    with %{code: code} <- Shipment.find_transition(match, @canceled_states, :desc) do
      fallback_code =
        case Shipment.find_transition(match, :driver_canceled, :desc) do
          nil -> "OTHER"
          _ -> "CARRIER_CANCELLED"
        end

      code || fallback_code
    end
  end

  defp get_order_state(%Match{state: state}) when state in @canceled_states,
    do: "CANCELLED"

  defp get_order_state(%Match{state: :completed, match_stops: [%{state: :delivered}]}),
    do: "DELIVERED"

  defp get_order_state(%Match{state: :completed, match_stops: [%{state: :returned}]}),
    do: "RETURNED"

  defp get_order_state(%Match{state: :picked_up, match_stops: [%{state: :pending}]}),
    do: "PICKED_UP"

  defp get_order_state(%Match{state: :picked_up, match_stops: [%{state: :en_route}]}),
    do: "EN_ROUTE_TO_DROPOFF"

  defp get_order_state(%Match{state: :picked_up, match_stops: [%{state: state}]})
       when state in [:arrived, :signed],
       do: "ARRIVED_AT_DROPOFF"

  defp get_order_state(%Match{state: state}),
    do: state |> Atom.to_string() |> String.upcase()

  def get_driver_tip(fees) do
    Enum.find(fees, %{}, &(&1.type == :driver_tip))
    |> Map.get(:amount, 0)
  end

  def get_parking_spot(match, to_state) do
    case Shipment.find_transition(match, to_state, :desc) do
      %{notes: notes} -> notes || ""
      _ -> ""
    end
  end

  def get_eta(%Match{} = match) do
    case match.eta do
      nil -> nil
      eta -> Map.get(eta, :arrive_at, nil)
    end
  end

  def get_eta(stops) when is_list(stops) do
    case stops do
      [] ->
        nil

      [stop] ->
        case Map.get(stop, :eta) do
          nil ->
            nil

          eta ->
            Map.get(eta, :arrive_at, nil)
        end
    end
  end

  # TODO: masked phone number
  def build_courier_info(match) do
    driver = Map.get(match, :driver) || %{}
    phone_number = Map.get(driver, :phone_number)
    current_location = Map.get(driver, :current_location)
    vehicles = Map.get(driver, :vehicles, %{})

    vehicle =
      Enum.find(
        vehicles,
        %{},
        &(&1.vehicle_class == match.vehicle_class)
      )

    {lng, lat} =
      if current_location do
        current_location.geo_location.coordinates
      else
        {nil, nil}
      end

    %{
      "id" => Map.get(driver, :id),
      "firstName" => Map.get(driver, :first_name),
      "lastName" => Map.get(driver, :last_name),
      "phoneNumber" => phone_number && ExPhoneNumber.format(phone_number, :e164),
      "maskedPhoneNumber" => phone_number && ExPhoneNumber.format(phone_number, :e164),
      "location" => %{
        "latitude" => lat,
        "longitude" => lng
      },
      "vehicle" => %{
        "make" => Map.get(vehicle, :make),
        "model" => Map.get(vehicle, :model),
        "color" => nil,
        "licensePlate" => Map.get(vehicle, :license_plate)
      }
    }
  end
end
