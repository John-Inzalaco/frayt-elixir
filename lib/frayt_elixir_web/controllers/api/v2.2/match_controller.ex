defmodule FraytElixirWeb.API.V2x2.MatchController do
  use FraytElixirWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match

  alias FraytElixirWeb.API.V2x2.Schemas.{
    CancelMatchRequest,
    MatchRequest,
    UpdateMatch,
    MatchEstimateResponse,
    MatchResponse
  }

  alias FraytElixirWeb.API.V2x1
  alias V2x1.Callbacks

  alias V2x1.Schemas.{
    UnprocessibleEntity,
    InvalidParameters,
    BadRequest,
    Forbidden,
    NotFound,
    Unauthorized
  }

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_api_account: 2,
      authorize_match: 2,
      authorize_shipper_for_api_account: 2
    ]

  alias FraytElixir.Matches

  alias FraytElixirWeb.FallbackController

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  plug :authorize_api_account

  plug :authorize_shipper_for_api_account

  plug :authorize_match when action in [:show, :delete]

  action_fallback FallbackController

  tags ["matches"]

  security [%{"authorization" => []}]

  operation :show,
    summary: "Get Match",
    parameters: [
      id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        description: "Match ID",
        example: "44e216c1-3ebc-4ce0-9a6b-1b94d9c2f25b",
        required: true
      ]
    ],
    responses: [
      ok: {"Match response", "application/json", MatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def show(%{assigns: %{match: match}} = conn, _) do
    render(conn, "show.json", match: match)
  end

  operation :delete,
    summary: "Cancel Match",
    parameters: [
      id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        description: "Match ID",
        example: "44e216c1-3ebc-4ce0-9a6b-1b94d9c2f25b",
        required: true
      ]
    ],
    request_body: {"Cancel params", "application/json", CancelMatchRequest},
    callbacks: %{
      "match_update" => %{
        "match.shipper.location.company.webhook_url" => Callbacks.match_webhook()
      }
    },
    responses: [
      ok: {"Match response", "application/json", MatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      bad_request: {"Bad Request", "application/json", BadRequest},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def delete(%{body_params: delete_params, assigns: %{match: match}} = conn, _attrs) do
    reason = delete_params |> OpenApiHelper.params_to_map() |> Map.get(:cancel_reason)

    with {:ok, match} <- Shipment.shipper_cancel_match(match, reason, restricted: true) do
      conn |> render("show.json", match: match)
    end
  end

  operation :create,
    summary: "Create an authorized match",
    request_body: {"Match params", "application/json", MatchRequest},
    callbacks: %{
      "match_update" => %{
        "match.shipper.location.company.webhook_url" => Callbacks.match_webhook()
      }
    },
    responses: [
      created: {"Match response", "application/json", MatchResponse},
      unprocessable_entity:
        {"Invalid parameters", "application/json",
         %OpenApiSpex.Schema{type: :object, oneOf: [UnprocessibleEntity, InvalidParameters]}},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def create(
        %{
          body_params: match_params,
          assigns: %{
            shipper: shipper
          }
        } = conn,
        _params
      ) do
    with attrs <- OpenApiHelper.params_to_map(match_params),
         {:ok, %Match{} = match} <- Matches.create_match(attrs, shipper) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", RoutesApiV2_1.api_match_path(conn, :show, match))
      |> render("show.json", match: match)
    end
  end

  operation :estimate,
    summary: "Get an estimate for a Match without authorizing",
    request_body: {"Match params", "application/json", MatchRequest},
    responses: [
      ok: {"Match response", "application/json", MatchEstimateResponse},
      unprocessable_entity:
        {"Invalid parameters", "application/json",
         %OpenApiSpex.Schema{type: :object, oneOf: [UnprocessibleEntity, InvalidParameters]}},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def estimate(
        %{
          body_params: match_params,
          assigns: %{
            shipper: shipper
          }
        } = conn,
        _params
      ) do
    with attrs <- OpenApiHelper.params_to_map(match_params),
         {:ok, %Match{} = match} <- Matches.create_estimate(attrs, shipper) do
      conn
      |> put_status(:ok)
      |> render("show.json", match: match)
    end
  end

  operation :update,
    summary: "Update Match",
    parameters: [
      id: [
        in: :path,
        type: %OpenApiSpex.Schema{type: :string},
        description: "Match ID",
        example: "44e216c1-3ebc-4ce0-9a6b-1b94d9c2f25b",
        required: true
      ]
    ],
    request_body:
      {"Update an existing match that has not been picked up yet", "application/json",
       UpdateMatch},
    callbacks: %{
      "match_update" => %{
        "match.shipper.location.company.webhook_url" => Callbacks.match_webhook()
      }
    },
    responses: [
      ok: {"Match response", "application/json", MatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      bad_request: {"Bad Request", "application/json", BadRequest},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def update(conn, _),
    do:
      FallbackController.call(
        conn,
        {:error, :forbidden, "Must use PATCH and not PUT to update a match"}
      )
end

defmodule FraytElixirWeb.API.V2x2.UpdateMatchController do
  use FraytElixirWeb, :controller
  alias FraytElixir.Shipment.{Match, MatchState}
  alias FraytElixir.Matches
  alias FraytElixirWeb.FallbackController
  alias FraytElixirWeb.API.V2x2.MatchView
  import FraytElixir.AtomizeKeys

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_api_account: 2,
      authorize_match: 2,
      authorize_shipper_for_api_account: 2
    ]

  plug :authorize_api_account
  plug :authorize_shipper_for_api_account
  plug :authorize_match when action in [:update]
  action_fallback FallbackController

  @updateable_match_states MatchState.cancelable_range()

  def update(
        %{body_params: update_params, assigns: %{match: %{state: state} = current_match}} = conn,
        _attrs
      )
      when state in @updateable_match_states do
    with attrs <-
           update_params |> atomize_keys() |> OpenApiHelper.params_to_map(),
         {:ok, %Match{} = match} <- Matches.api_update_match(current_match, attrs) do
      conn
      |> put_status(:ok)
      |> put_resp_header("location", RoutesApiV2_1.api_match_path(conn, :show, match))
      |> put_view(MatchView)
      |> render("show.json", match: match)
    end
  end

  def update(conn, _params) do
    FallbackController.call(
      conn,
      {:error, :forbidden, "Match may not be updated in its current state."}
    )
  end
end
