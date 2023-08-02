defmodule FraytElixirWeb.Webhook.HubspotController do
  use FraytElixirWeb, :controller
  require Logger
  alias FraytElixir.Hubspot
  alias FraytElixirWeb.FallbackController

  action_fallback FallbackController

  plug :authorize_webhook

  def handle_webhooks(conn, %{
        "_json" => changes
      }) do
    changes
    |> Task.async_stream(fn
      change ->
        case change do
          %{
            "subscription_type" => "company.propertyChange",
            "property_name" => "hubspot_owner_id",
            "object_id" => company_hubspot_id,
            "property_value" => hubspot_owner_id
          } ->
            Hubspot.sync_sales_rep(company_hubspot_id, hubspot_owner_id)

          _ ->
            Logger.error("Invalid webhook subscription. #{inspect(change)}")
            {:error, :invalid_webhook}
        end
    end)
    |> Enum.into([], fn {:ok, res} -> res end)
    |> Enum.filter(fn res ->
      case res do
        {:ok, _} -> false
        {:error, _} -> true
      end
    end)
    |> Enum.count()
    |> case do
      0 ->
        render(conn, "success.json", %{})

      error_count ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("error.json", %{error_count: error_count, total_count: Enum.count(changes)})
    end
  end

  def authorize_webhook(%{params: params} = conn, _) do
    if Map.get(params, "api_key") == Application.get_env(:frayt_elixir, :hubspot_webhook_api_key) do
      conn
    else
      FallbackController.call(conn, {:error, :not_found})
    end
  end
end
