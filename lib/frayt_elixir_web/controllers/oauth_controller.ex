defmodule FraytElixirWeb.OauthController do
  use FraytElixirWeb, :controller
  use PhoenixSwagger
  use OpenApiSpex.ControllerSpecs
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.ApiAccount

  alias FraytElixirWeb.API.V2x1.Schemas.{
    OauthParams,
    OauthResponse,
    Forbidden,
    InvalidParameters
  }

  plug OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true

  action_fallback FraytElixirWeb.FallbackController

  swagger_path :authenticate do
    post("/oauth/token")

    description(
      "Acquire JWT Token. The `token` in the API response is a Bearer token that is used to authenticate private routes: E.g. `\"Authorization\": \"Bearer ${token}\"`"
    )

    response(200, "Success")
    produces("application/json")

    parameters do
      client_id(:query, :string, "Client ID")
      secret(:query, :string, "Secret")
    end
  end

  operation :authenticate,
    summary: "Get bearer token for use in protected API calls`",
    request_body: {"Credentials", "application/json", OauthParams},
    responses: [
      ok: {"Success", "application/json", OauthResponse},
      unprocessable_entity: {"Invalid Parameters", "application/json", InvalidParameters},
      forbidden: {"Invalid Credentials", "application/json", Forbidden}
    ],
    tags: ["oauth"]

  def authenticate(
        %{body_params: %OauthParams{client_id: client_id, secret: secret}} = conn,
        _params
      ) do
    with {:ok, %ApiAccount{} = api_account} <-
           Accounts.authenticate_client_secret(client_id, secret),
         {:ok, token, _claims} <-
           FraytElixir.Guardian.encode_and_sign(api_account, %{"aud" => "frayt_api"}) do
      render(conn, "authenticate.json", token: token)
    end
  end
end
