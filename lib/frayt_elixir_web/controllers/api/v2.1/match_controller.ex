defmodule FraytElixirWeb.API.V2x1.MatchController do
  use FraytElixirWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FraytElixirWeb.API.V2x1.Callbacks

  alias FraytElixirWeb.API.V2x1.Schemas.{
    MatchRequest,
    SimpleMatchResponse,
    UnprocessibleEntity,
    InvalidParameters,
    BadRequest,
    Forbidden,
    NotFound,
    Unauthorized
  }

  alias FraytElixirWeb.API.MatchController

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_api_account: 2,
      authorize_match: 2,
      authorize_shipper_for_api_account: 2
    ]

  alias FraytElixir.Matches
  alias FraytElixir.Shipment.Match

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  plug :authorize_api_account

  plug :authorize_shipper_for_api_account

  plug :authorize_match when action in [:show, :delete]

  action_fallback FraytElixirWeb.FallbackController

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
      ok: {"Match response", "application/json", SimpleMatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def show(conn, params) do
    MatchController.show(conn, params |> Map.put("id", Map.get(params, :id)))
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
    callbacks: %{
      "match_update" => %{
        "match.shipper.location.company.webhook_url" => Callbacks.match_webhook()
      }
    },
    responses: [
      ok: {"Match response", "application/json", SimpleMatchResponse},
      not_found: {"Not Found", "application/json", NotFound},
      forbidden: {"Forbidden", "application/json", Forbidden},
      bad_request: {"Bad Request", "application/json", BadRequest},
      unauthorized: {"No Credentials", "application/json", Unauthorized}
    ]

  def delete(conn, params),
    do: MatchController.delete(conn, params |> Map.put("id", Map.get(params, :id)))

  operation :create,
    summary: "Create an authorized match",
    request_body: {"Match params", "application/json", MatchRequest},
    callbacks: %{
      "match_update" => %{
        "match.shipper.location.company.webhook_url" => Callbacks.match_webhook()
      }
    },
    responses: [
      created: {"Match response", "application/json", SimpleMatchResponse},
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
        _match_params
      ) do
    with match_attrs <-
           match_params |> OpenApiHelper.params_to_map() |> Map.put(:shipper, shipper),
         {:ok, %Match{} = match} <-
           match_attrs
           |> Matches.convert_attrs_to_multi_stop()
           |> Matches.create_match(shipper) do
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
      ok: {"Match response", "application/json", SimpleMatchResponse},
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
    with match_attrs <- OpenApiHelper.params_to_map(match_params),
         {:ok, %Match{} = match} <-
           match_attrs
           |> Matches.convert_attrs_to_multi_stop()
           |> Matches.create_estimate(shipper) do
      conn
      |> put_status(:ok)
      |> render("show.json", match: match)
    end
  end
end
