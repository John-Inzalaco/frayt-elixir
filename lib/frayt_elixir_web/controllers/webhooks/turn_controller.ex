defmodule FraytElixirWeb.Webhook.TurnController do
  use FraytElixirWeb, :controller
  require Logger
  alias FraytElixirWeb.FallbackController
  alias FraytElixir.Screenings

  action_fallback FallbackController

  def handle_webhooks(
        conn,
        %{
          "original_state" => _,
          "worker_id" => turn_id
        } = params
      ) do
    Logger.notice("Received webhook from turn for worked #{turn_id}")

    background_check = Screenings.get_background_check_by_turn_id(turn_id)

    case Screenings.update_background_check_turn_status(background_check, params) do
      {:ok, _driver} ->
        send_resp(conn, :no_content, "")

      result ->
        Logger.error(
          "ERROR! failed to process webhook from turn for worker #{turn_id}. #{inspect(result)}"
        )

        result
    end
  end

  def handle_webhooks(conn, _params) do
    send_resp(conn, :no_content, "")
  end
end
