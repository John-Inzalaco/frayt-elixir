defmodule FraytElixirWeb.API.Internal.MatchController do
  use FraytElixirWeb, :controller
  use Params

  import FraytElixir.MapConverter
  import FraytElixirWeb.UrlHelper

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_match: 2,
      authorize_shipper: 2,
      maybe_authorize_shipper: 2
    ]

  alias FraytElixir.{Matches, Shipment}
  alias Shipment.Match
  alias FraytElixirWeb.{FallbackController, ChangesetParams}
  alias FraytElixir.Accounts.Shipper
  alias FraytElixirWeb.ChangesetParams

  plug :authorize_shipper when action in [:index, :delete, :duplicate]
  plug :maybe_authorize_shipper when action in [:update, :create, :show]
  plug :authorize_match when action in [:update, :delete, :duplicate]

  action_fallback FallbackController

  defparams(
    index_params(%{
      states: :string,
      search: :string,
      location_id: :string,
      shipper_id: :string,
      page: [field: :integer, default: 0],
      per_page: [field: :integer, default: 10],
      order_by: [field: :string, default: "inserted_at"],
      order: [field: :string, default: "asc"]
    })
  )

  def index(%{assigns: %{current_shipper: shipper}} = conn, params) do
    with {:ok, filters} <- index_params(params) |> ChangesetParams.get_data() do
      filters = convert_key_value_to!(filters, :atom, [:order, :order_by, :states])

      {matches, page_count} = Shipment.list_shipper_matches(shipper, filters)

      render(conn, "index.json", matches: matches, page_count: page_count)
    end
  end

  @item_params %{
    description: :string,
    weight: :float,
    volume: :integer,
    pieces: :integer,
    width: :integer,
    length: :integer,
    height: :integer,
    declared_value: :integer,
    type: :string,
    barcode: :string,
    barcode_pickup_required: :boolean,
    barcode_delivery_required: :boolean
  }

  @stop_params %{
    destination_address: :string,
    destination_place_id: :string,
    dropoff_by: :string,
    has_load_fee: :boolean,
    needs_pallet_jack: :boolean,
    index: :integer,
    po: :string,
    delivery_notes: :string,
    signature_required: :boolean,
    signature_type: Shipment.MatchStopSignatureType.Type,
    signature_instructions: :string,
    destination_photo_required: :boolean,
    recipient: %{
      name: :string,
      email: :string,
      phone_number: :string,
      notify: :boolean
    },
    self_recipient: :boolean,
    items: [@item_params]
  }

  @match_params %{
    contract_id: :string,
    optimize: :boolean,
    coupon_code: :string,
    origin_address: :string,
    origin_place_id: :string,
    service_level: :integer,
    vehicle_class: :integer,
    scheduled: :boolean,
    pickup_at: :string,
    dropoff_at: :string,
    unload_method: :string,
    pickup_notes: :string,
    po: :string,
    self_sender: :boolean,
    bill_of_lading_required: :boolean,
    origin_photo_required: :boolean,
    sender: %{
      name: :string,
      email: :string,
      phone_number: :string,
      notify: :boolean
    },
    stops: [@stop_params],
    platform: :string,
    preferred_driver_id: :string
  }

  defparams(create_match_params(@match_params))

  defparams(
    update_match_params(%{
      @match_params
      | stops: [
          @stop_params
          |> Map.put(:id, :string)
          |> Map.put(:items, [Map.put(@item_params, :id, :string)])
        ]
    })
  )

  def show(conn, %{"id" => id}) do
    case Shipment.get_match(id) do
      %Match{} = match -> render(conn, "show.json", match: match)
      nil -> {:error, :not_found}
    end
  end

  defparams(
    update_live_match_params(%{
      rating: :integer,
      rating_reason: :string,
      platform: :string,
      preferred_driver_id: :string
    })
  )

  def create(%{assigns: %{current_shipper: shipper, version: version}} = conn, params) do
    with {:ok, attrs} <- params |> create_match_params() |> ChangesetParams.get_data(),
         {:ok, %Match{} = match} <- Matches.create_estimate(attrs, shipper) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", get_api_match_url(version, match))
      |> render("show.json", match: match)
    end
  end

  def duplicate(
        %{assigns: %{version: version, match: orig_match}} = conn,
        params
      ) do
    with {:ok, attrs} <- params |> update_match_params() |> ChangesetParams.get_data(),
         {:ok, match} <- Matches.duplicate_match(orig_match, attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", get_api_match_url(version, match))
      |> render("show.json", match: match)
    end
  end

  def update(
        %{assigns: %{match: match, current_shipper: shipper}} = conn,
        %{
          "state" => "authorized"
        }
      ) do
    with %Shipper{} <- shipper,
         {:ok, %Match{} = match} <-
           Matches.update_and_authorize_match(match, %{}, shipper) do
      render(conn, "show.json", match: match)
    else
      nil -> {:error, :forbidden}
      e -> e
    end
  end

  def update(
        %{assigns: %{match: %{state: :pending} = match, current_shipper: shipper}} = conn,
        params
      ) do
    with {:ok, attrs} <- params |> update_match_params() |> ChangesetParams.get_data(),
         {:ok, %Match{} = match} <-
           Matches.update_estimate(match, attrs, shipper) do
      render(conn, "show.json", match: match)
    end
  end

  def update(%{assigns: %{match: match, current_shipper: shipper}} = conn, params) do
    with %Shipper{} <- shipper,
         {:ok, attrs} <- params |> update_live_match_params() |> ChangesetParams.get_data(),
         {:ok, %Match{} = match} <- Matches.update_match(match, attrs) do
      render(conn, "show.json", match: match)
    else
      nil -> {:error, :forbidden}
      e -> e
    end
  end

  def delete(
        %{assigns: %{current_shipper: %Shipper{id: shipper_id}}} = conn,
        %{"id" => match_id} = attrs
      ) do
    reason = Map.get(attrs, "reason", nil)

    with %Match{shipper: %Shipper{id: ^shipper_id}} = match <-
           Shipment.get_match(match_id),
         {:ok, match} <- Shipment.shipper_cancel_match(match, reason) do
      render(conn, "show.json", match: match)
    else
      %Match{} -> {:error, :forbidden, "Invalid match"}
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
