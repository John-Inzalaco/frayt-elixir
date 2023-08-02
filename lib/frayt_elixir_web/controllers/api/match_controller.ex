defmodule FraytElixirWeb.API.MatchController do
  use FraytElixirWeb, :controller
  use PhoenixSwagger

  alias FraytElixir.Matches
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixirWeb.FallbackController
  alias FraytElixir.Accounts.{Shipper, Company, ApiAccount, Location}
  alias FraytElixir.Repo
  alias Ecto.Changeset
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.API.Internal.MatchView

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_api_account: 2,
      authorize_shipper_for_api_account: 2,
      get_current_api_account: 1
    ]

  plug(:authorize_api_account when action in [:create, :index, :delete, :show, :status])

  plug(:authorize_shipper_for_api_account when action in [:create])

  action_fallback(FallbackController)

  use Params

  defparams(
    create_estimate_params(%{
      origin_address!: :string,
      destination_address!: :string,
      service_level!: :integer,
      vehicle_class: [field: :integer, default: nil],
      unload_method: [field: :string],
      pieces!: :integer,
      weight!: :integer,
      dimensions_length!: :integer,
      dimensions_width!: :integer,
      dimensions_height!: :integer,
      load_fee: [field: :boolean, default: false],
      contract: [field: :string, default: nil]
    })
  )

  defparams(
    create_match_params(%{
      estimate!: :string,
      dimensions_length!: :integer,
      dimensions_width!: :integer,
      dimensions_height!: :integer,
      weight!: :integer,
      pieces!: :integer,
      vehicle_class: [field: :integer],
      unload_method: [field: :string],
      shipper_email: [field: :string],
      load_unload: [field: :boolean, default: false],
      pickup_notes: [field: :string],
      dropoff_notes: [field: :string],
      description: [field: :string],
      job_number: [field: :string],
      recipient_name: [field: :string],
      recipient_phone: [field: :string],
      recipient_email: [field: :string],
      scheduled_pickup: [field: :utc_datetime],
      scheduled_dropoff: [field: :utc_datetime],
      identifier: [field: :string],
      webhook: [field: :string]
    })
  )

  defparams(
    list_matches_params(%{
      limit: [field: :integer, default: 10],
      cursor: [field: :integer, default: 0],
      sort_field: [field: :string, default: ""],
      descending: [field: :boolean, default: false]
    })
  )

  swagger_path :create_estimate do
    post("/estimates")
    description("Create new estimate")
    response(201, "Success")
    consumes("application/json")
    produces("application/json")

    parameters do
      origin_address(:query, :string, "Origin Address", required: true)
      destination_address(:query, :string, "Destination Address", required: true)
      service_level(:query, :string, "Service Level", required: true)
      vehicle_class(:query, :string, "Vehicle Class", required: false)
      pieces(:query, :integer, "Pieces", required: true)
      weight(:query, :integer, "Weight", required: true)
      dimensions_length(:query, :integer, "Length", required: true)
      dimensions_width(:query, :integer, "Width", required: true)
      dimensions_height(:query, :integer, "Height", required: true)
      contract(:query, :string, "Contract")
      load_fee(:query, :boolean, "Load fee")
    end
  end

  def create_estimate(conn, match_params) do
    company =
      case get_current_api_account(conn) do
        %ApiAccount{company: %Company{} = company} ->
          company

        _ ->
          nil
      end

    shipper = Shipment.get_company_shipper(company)

    with %Changeset{valid?: true} = changeset <-
           create_estimate_params(match_params),
         match_attrs <- Params.to_map(changeset) |> Matches.convert_attrs_to_multi_stop(),
         {:ok, match} <-
           Matches.create_estimate(match_attrs, shipper) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.estimates_path(conn, :show, match))
      |> put_view(MatchView)
      |> render("show.json", match: match)
    end
  end

  swagger_path :create do
    post("/matches")
    description("Create match")
    response(201, "Success")
    consumes("application/json")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      estimate(:query, :string, "Estimate ID", required: true)
      dimensions_length(:query, :integer, "Length", required: true)
      dimensions_width(:query, :integer, "Width", required: true)
      dimensions_height(:query, :integer, "Height", required: true)
      weight(:query, :integer, "Weight", required: true)
      pieces(:query, :integer, "Pieces", required: true)
      vehicle_class(:query, :string, "Vehicle Class", required: false)
      shipper_email(:query, :string, "Shipper Email")
      load_unload(:query, :boolean, "Load/Unload")
      pickup_notes(:query, :string, "Pickup Notes")
      dropoff_notes(:query, :string, "Dropoff Notes")
      description(:query, :string, "Description")
      job_number(:query, :string, "Job Number")
      recipient_name(:query, :string, "Recipient Name")
      recipient_phone(:query, :string, "Recipient Phone")
      recipient_email(:query, :string, "Recipient Email")

      scheduled_pickup(:query, :string, "Scheduled Pick up Date/Time (ISO format)",
        examples: ["2020-09-28T09:31"]
      )

      scheduled_dropoff(:query, :string, "Scheduled Drop off Date/Time (ISO format)",
        example: "2020-09-28T18:31"
      )

      identifier(:query, :string, "Identifier")
    end
  end

  def create(
        %{
          assigns: %{
            shipper: shipper
          }
        } = conn,
        match_params
      ) do
    with %Changeset{valid?: true} = changeset <-
           create_match_params(match_params),
         %{estimate: estimate_id} = attrs <-
           changeset
           |> Params.to_map(),
         estimate <- Shipment.get_match!(estimate_id),
         attrs <-
           attrs
           |> Map.put(:scheduled, !!Map.get(attrs, :scheduled_pickup))
           |> Matches.convert_attrs_to_multi_stop(estimate),
         {:ok, match} <-
           Matches.update_and_authorize_match(
             estimate,
             attrs,
             shipper
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.api_match_path(conn, :show, match))
      |> put_view(MatchView)
      |> render("show.json", match: match)
    end
  end

  swagger_path :show do
    get("/matches/{id}")
    description("Get match")
    response(200, "Success")
    produces("application/json")

    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Estimate ID")
    end
  end

  def show(
        %{
          assigns: %{
            api_account: %ApiAccount{
              company_id: company_id
            }
          }
        } = conn,
        %{"id" => match_id}
      ) do
    match = match_id |> Shipment.get_match() |> Repo.preload(shipper: [:location, :address])

    case match do
      %Match{shipper: %Shipper{location: %Location{company_id: ^company_id}}} = match ->
        conn |> put_view(MatchView) |> render("show.json", match: match)

      %Match{} ->
        FallbackController.call(conn, {:error, :forbidden, "Invalid match"})

      nil ->
        FallbackController.call(conn, {:error, :not_found})
    end
  end

  swagger_path :status do
    get("/matches/{id}/status")
    description("Get match status")
    response(200, "Success")
    produces("application/json")

    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Estimate ID")
    end
  end

  def status(
        %{assigns: %{api_account: %ApiAccount{company_id: company_id}}} = conn,
        %{"id" => match_id}
      ) do
    with %Match{shipper: %Shipper{location: %Location{company_id: ^company_id}}} = match <-
           Shipment.get_match(match_id)
           |> Repo.preload([:match_stops, shipper: [:location]], force: true),
         status <- DisplayFunctions.deprecated_match_status(match) do
      conn |> put_view(MatchView) |> render("status.json", status: status)
    else
      %Match{} -> FallbackController.call(conn, {:error, :forbidden, "Invalid match"})
      nil -> FallbackController.call(conn, {:error, :not_found})
      _ -> FallbackController.call(conn, {:error, :not_found})
    end
  end

  swagger_path :index do
    get("/matches")
    description("List matches for logged in account")
    response(200, "Success")
    produces("application/json")

    security([%{Bearer: []}])

    parameters do
      limit(:query, :integer, "Number of results")
      cursor(:query, :integer, "Start index")
      sort_field(:query, :string, "Sort field")
      descending(:query, :boolean, "Sort direction")
    end
  end

  def index(conn, params) do
    with %{api_account: %ApiAccount{company_id: company_id}} <- conn.assigns,
         %Ecto.Changeset{valid?: true} = params_changeset <- list_matches_params(params) do
      attrs = Params.to_map(params_changeset)

      attrs =
        attrs
        |> Map.put(:order_by, attrs.sort_field)
        |> Map.put(:offset, attrs.cursor)
        |> Map.drop([:cursor, :sort_field])

      matches = Shipment.list_matches_for_company(company_id, attrs)

      conn |> put_view(MatchView) |> render("index.json", matches: matches)
    end
  end

  swagger_path :delete do
    post("/matches/{id}/cancel")
    description("Cancel match")
    response(200, "Success")
    produces("application/json")

    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Estimate ID")
      reason(:query, :string, "Reason for cancellation", required: false)
    end
  end

  def delete(
        %{
          assigns: %{
            api_account: %ApiAccount{
              company_id: company_id
            }
          }
        } = conn,
        %{"id" => match_id} = attrs
      ) do
    reason = Map.get(attrs, "reason", nil)

    with %Match{
           shipper: %Shipper{location: %Location{company_id: ^company_id}}
         } = match <-
           Shipment.get_match(match_id) |> Repo.preload(shipper: [:location]),
         {:ok, match} <- Shipment.shipper_cancel_match(match, reason, restricted: true) do
      conn |> put_view(MatchView) |> render("show.json", match: match)
    else
      %Match{} ->
        FallbackController.call(conn, {:error, :forbidden, "Invalid match"})

      nil ->
        FallbackController.call(conn, {:error, :not_found})

      err ->
        err
    end
  end
end
