defmodule FraytElixirWeb.API.Internal.DriverMatchStopController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Drivers

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_driver: 2,
      authorize_driver_match: 2,
      authorize_driver_match_stop: 2,
      update_driver_location: 2
    ]

  plug(:authorize_driver)
  plug(:update_driver_location)
  plug(:authorize_driver_match)
  plug(:authorize_driver_match_stop)

  action_fallback(FraytElixirWeb.FallbackController)

  def update(%{assigns: %{match_stop: stop}} = conn, %{"state" => "arrived"}) do
    with {:ok, match} <- Drivers.arrived_at_stop(stop) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match)
    end
  end

  def update(
        %{assigns: %{match_stop: stop}} = conn,
        %{
          "state" => "signed",
          "image" => signature_photo,
          "receiver_name" => receiver_name
        }
      ) do
    with {:ok, match} <- Drivers.sign_stop(stop, signature_photo, receiver_name) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match)
    end
  end

  def update(
        %{assigns: %{match_stop: stop}} = conn,
        %{"state" => "delivered"} = params
      ) do
    with {:ok, match, nps_score_id} <-
           Drivers.deliver_stop(stop, Map.get(params, "destination_photo")) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match, nps_score_id: nps_score_id)
    end
  end

  def update(%{assigns: %{match_stop: stop}} = conn, %{"state" => "undeliverable"} = attrs) do
    reason = Map.get(attrs, "reason")

    with {:ok, match} <- Drivers.undeliverable_stop(stop, reason) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match)
    end
  end

  def toggle_en_route(%{assigns: %{match_stop: stop}} = conn, _) do
    with {:ok, match} <- Drivers.toggle_en_route(stop) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match)
    end
  end
end
