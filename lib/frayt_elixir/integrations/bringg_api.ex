defmodule FraytElixir.Integrations.BringgApi do
  use HTTPoison.Base

  def process_request_url(url) do
    Application.get_env(:frayt_elixir, :bringg_api_url) <> url
  end

  def process_request_headers(headers) do
    [{"Content-Type", "application/json"}] ++ headers
  end

  def get_merchant_creds(merchant_uuid) do
    post(
      "/open_fleet_administration/#{Application.get_env(:frayt_elixir, :bringg_self_fleet_uuid)}/#{merchant_uuid}",
      "",
      [],
      hackney: [
        basic_auth: {
          Application.get_env(:frayt_elixir, :bringg_admin_client_id),
          Application.get_env(:frayt_elixir, :bringg_admin_client_secret)
        }
      ]
    )
  end

  def get_token(%{client_id: client_id, secret: secret}) do
    body =
      Jason.encode!(%{
        grant_type: "client_credentials",
        client_id: client_id,
        client_secret: secret
      })

    {:ok, %HTTPoison.Response{body: body}} = post("/oauth/token", body)

    case Jason.decode!(body) do
      %{"access_token" => access_token} -> access_token
      %{"error" => _} -> nil
    end
  end
end
