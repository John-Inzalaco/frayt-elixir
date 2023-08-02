defmodule FraytElixirWeb.Webhook.WalmartController do
  use FraytElixirWeb, :controller
  use Params

  alias FraytElixirWeb.FallbackController
  alias Ecto.Changeset
  alias FraytElixir.Matches
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Accounts.Location
  alias FraytElixir.Accounts.Shipper
  alias FraytElixir.Accounts.Company
  alias FraytElixir.Integrations.Walmart

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_api_account: 2
    ]

  plug(:authorize_api_account)
  plug(:validate_walmart_delivery when action in [:update, :cancel, :show, :update_tip])
  action_fallback(FallbackController)

  defparams(
    create_delivery_params(%{
      external_order_id!: :string,
      external_delivery_id: :string,
      order_info: %{
        total_weight: :float,
        total_volume: :float,
        total_quantity: :integer,
        size: :string,
        order_line_items: [
          %{
            id: :string,
            quantity: [field: :integer, default: 0],
            ordered_weight: [field: :float, default: 0.0],
            uom: [field: :string, default: "LB"],
            height: [field: :float, default: 0.0],
            width: [field: :float, default: 0.0],
            length: [field: :float, default: 0.0],
            uom_dimension: [field: :string, default: "IN"]
          }
        ],
        barcode_info: [
          %{
            barcode: :string
          }
        ]
      },
      pickup_info!: %{
        pickup_address: %{
          address_line1: [field: :string, default: nil],
          address_line2: [field: :string, default: nil],
          city: [field: :string, default: nil],
          state: [field: :string, default: nil],
          zip_code: [field: :string, default: nil],
          country: [field: :string, default: nil]
        },
        pickup_location: %{
          latitude: [field: :float, default: nil],
          longitude: [field: :float, default: nil]
        },
        pickup_contact: %{
          first_name!: :string,
          last_name: :string,
          phone!: :string
        },
        pickup_instruction: :string
      },
      drop_off_info: %{
        drop_off_address!: %{
          address_line1: [field: :string, default: nil],
          address_line2: [field: :string, default: nil],
          city: [field: :string, default: nil],
          state: [field: :string, default: nil],
          zip_code: [field: :string, default: nil],
          country: [field: :string, default: nil]
        },
        drop_off_location: %{
          latitude: [field: :float, default: nil],
          longitude: [field: :float, default: nil]
        },
        drop_off_contact: %{
          first_name!: :string,
          last_name: :string,
          phone: :string
        },
        drop_off_instruction: :string,
        signature_required: :boolean,
        proof_of_delivery_required: :boolean,
        is_contactless_delivery: :boolean
      },
      is_autonomous_delivery: :boolean,
      contains_alcohol: :boolean,
      contains_pharmacy: :boolean,
      contains_hazmat: :boolean,
      is_id_verification_required: :boolean,
      delivery_window_start_time!: :string,
      delivery_window_end_time!: :string,
      pickup_window_start_time!: :string,
      pickup_window_end_time!: :string,
      client_id!: :string,
      external_store_id: :string,
      tip: :integer,
      batch_id: :string,
      seq_number: :integer,
      osn: :string,
      customer_id: :string,
      delivery_method: :string,
      delivery_priority: :string
    })
  )

  defparams(
    cancel_delivery_params(%{
      cancel_reason!: :string,
      comment: :string
    })
  )

  defparams(
    update_driver_tip_params(%{
      tip!: :integer
    })
  )

  def create(%{assigns: %{api_account: %{company: company}}} = conn, params) do
    with %Changeset{valid?: true} = changeset <-
           create_delivery_params(params),
         delivery_attrs <- Params.to_map(changeset),
         match_attrs <-
           delivery_attrs
           |> convert_params()
           |> Map.put(:meta, delivery_attrs)
           |> Matches.convert_attrs_to_multi_stop()
           |> Map.put(:parking_spot_required, true),
         shipper <- Shipment.get_company_shipper(company),
         {:ok, %Match{} = match} <- Matches.create_match(match_attrs, shipper) do
      render(conn, "match.json", %{match: match})
    else
      {:error, _, changeset, _data} ->
        bad_request(conn, changeset)

      %Changeset{} = changeset ->
        bad_request(conn, changeset)
    end
  end

  def update(%{assigns: %{match: match}} = conn, params) do
    with %Changeset{valid?: true} = changeset <- create_delivery_params(params),
         delivery_attrs <-
           Params.to_map(changeset)
           |> convert_params()
           |> Matches.convert_attrs_to_multi_stop(),
         {:ok, %Match{} = match} <- Matches.update_match(match, delivery_attrs) do
      render(conn, "match.json", %{match: match})
    end
  end

  def show(conn, %{"delivery_id" => id}) do
    with %Match{} = match <- Shipment.get_match(id) do
      render(conn, "show_match.json", %{match: match})
    end
  end

  def cancel(%{assigns: %{match: match}} = conn, params) do
    with %Changeset{valid?: true} = changeset <- cancel_delivery_params(params),
         %{cancel_reason: code} = cancel_attrs <- Params.to_map(changeset),
         {:ok, %Match{} = match} <-
           Shipment.shipper_cancel_match(match, %{
             code: code,
             notes: Map.get(cancel_attrs, :comment, nil)
           }) do
      mst = Enum.find(match.state_transitions, &(&1.to == :canceled))
      render(conn, "cancel_response.json", %{match_state_transition: mst})
    end
  end

  def update_tip(%{assigns: %{match: match}} = conn, params) do
    with %Changeset{valid?: true} = cs <- update_driver_tip_params(params),
         %{tip: tip} <- Params.to_map(cs),
         {:ok, match} <- Walmart.update_tip_price(match, tip) do
      render(conn, "updated_tip_resp.json", %{match: match})
    else
      {:error, _, changeset, _data} ->
        bad_request(conn, changeset)

      %Changeset{} = changeset ->
        bad_request(conn, changeset)
    end
  end

  defp bad_request(conn, cs) do
    conn
    |> put_status(:bad_request)
    |> render("error_message.json", %{changeset: cs, code: :walmart_error})
  end

  def validate_walmart_delivery(
        %{
          assigns: %{api_account: %{company: %Company{id: company_id}}},
          params: %{"delivery_id" => match_id}
        } = conn,
        _
      ) do
    case Shipment.get_match(match_id) do
      %Match{shipper: %Shipper{location: %Location{company_id: ^company_id}}} = match ->
        assign(conn, :match, match)

      _ ->
        FallbackController.call(conn, {:error, :forbidden})
    end
  end

  defp convert_params(params) do
    pickup_info = params.pickup_info
    drop_off_info = params.drop_off_info

    %{
      items: extract_order_info(params),
      pickup_notes: Map.get(pickup_info, :pickup_instruction),
      delivery_notes: Map.get(drop_off_info, :drop_off_instruction),
      # admin_notes: "\n",
      identifier: Map.get(params, :external_order_id),
      po: Map.get(params, :external_order_id),
      pickup_at: params.pickup_window_end_time,
      dropoff_at: params.delivery_window_end_time,
      # match_stop_identifier: to_string(destination_waypoint[:id]),
      scheduled: not is_nil(params.pickup_window_end_time),
      origin_address: build_address(pickup_info.pickup_address, pickup_info.pickup_location),
      destination_address:
        build_address(
          drop_off_info.drop_off_address,
          drop_off_info.drop_off_location
        ),
      tip: params[:tip] || 0,
      service_level: 1,
      autoselect_vehicle_class: true,
      external_delivery_id: params.external_delivery_id,
      delivery_window_end_time: params.delivery_window_end_time,
      pickup_window_end_time: params.pickup_window_end_time,
      sender: extract_contact_info(pickup_info),
      self_sender: false,
      signature_required: drop_off_info.signature_required,
      destination_photo_required: drop_off_info.proof_of_delivery_required
    }
    |> Map.merge(extract_contact_info(params.drop_off_info))
  end

  defp extract_contact_info(%{drop_off_contact: recipient}) do
    %{
      recipient_phone: parse_phone_number(recipient.phone),
      notify: false,
      recipient_name: FraytElixirWeb.DisplayFunctions.full_name(recipient)
    }
  end

  defp extract_contact_info(%{pickup_contact: sender}) do
    %{
      phone_number: parse_phone_number(sender.phone),
      notify: false,
      name: FraytElixirWeb.DisplayFunctions.full_name(sender)
    }
  end

  defp extract_order_info(%{order_info: %{order_line_items: order_line_items}})
       when not is_nil(order_line_items) and length(order_line_items) > 0 do
    Enum.map(order_line_items, &extract_item_info/1)
  end

  defp extract_order_info(%{order_info: order_info}) do
    %{total_volume: volume, total_weight: weight} = order_info
    pieces = convert_pieces(order_info.total_quantity)

    [
      %{
        width: 0,
        height: 0,
        length: 0,
        volume: if(volume, do: ceil(volume * 1728 / pieces), else: 1),
        weight: convert_weight(weight, pieces),
        pieces: pieces,
        declared_value: 1000
      }
    ]
  end

  defp extract_item_info(order_line_item) do
    %{uom_dimension: uom_dimension, ordered_weight: weight} = order_line_item
    pieces = convert_pieces(order_line_item.quantity)

    %{
      width: convert_measurement_to_inches(order_line_item.width, uom_dimension) / pieces,
      height: convert_measurement_to_inches(order_line_item.height, uom_dimension) / pieces,
      length: convert_measurement_to_inches(order_line_item.length, uom_dimension) / pieces,
      weight: convert_weight(weight, pieces),
      pieces: pieces,
      external_id: order_line_item.id,
      declared_value: 1000
    }
  end

  defp convert_weight(weight, pieces) when is_number(weight) and is_number(pieces),
    do: weight / pieces

  defp convert_weight(_weight, _pieces), do: 250

  defp convert_pieces(pieces) when is_number(pieces), do: pieces
  defp convert_pieces(_pieces), do: 2

  defp convert_measurement_to_inches(nil, _uom), do: 0

  defp convert_measurement_to_inches(value, "FT"), do: value * 12

  defp convert_measurement_to_inches(value, _uom), do: value

  defp build_address(
         %{
           address_line1: address,
           city: city,
           country: _country,
           state: state,
           zip_code: zip
         } = params,
         %{
           longitude: lng,
           latitude: lat
         }
       ) do
    formatted_address =
      if Map.get(params, :address2) do
        %{
          formatted_address: "#{address}, #{params.address2}, #{city}, #{state} #{zip}",
          address2: params.address2
        }
      else
        %{
          formatted_address: "#{address}, #{city}, #{state} #{zip}"
        }
      end

    if is_nil(lat) or is_nil(lng) do
      %{
        address: address,
        city: city,
        state: state,
        zip: zip
      }
      |> Map.merge(formatted_address)
    else
      %{
        address: address,
        city: city,
        state: state,
        zip: zip,
        geo_location: %Geo.Point{coordinates: {lng, lat}}
      }
      |> Map.merge(formatted_address)
    end
  end

  defp parse_phone_number(number) do
    case FraytElixir.Type.PhoneNumber.cast(number) do
      {:ok, _phone} -> number
      _ -> nil
    end
  end
end
