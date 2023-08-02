defmodule FraytElixirWeb.API.Internal.DriverMatchController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Drivers
  alias FraytElixirWeb.UploadHelper
  alias FraytElixir.Shipment.MatchWorkflow

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_driver: 2,
      authorize_driver_match: 2,
      update_driver_location: 2,
      validate_driver_registration: 2
    ]

  plug :authorize_driver

  plug :update_driver_location when action in [:update, :toggle_en_route]

  plug :authorize_driver_match when action in [:update, :show, :toggle_en_route]

  plug :validate_driver_registration when action in [:update, :toggle_en_route]

  action_fallback(FraytElixirWeb.FallbackController)

  def available(%{assigns: %{current_driver: driver}} = conn, params) do
    batch_id = Map.get(params, "id")

    available_matches = Drivers.list_available_matches_for_driver(driver, batch_id)

    conn
    |> render_version("index.json", matches: available_matches)
  end

  def missed(%{assigns: %{current_driver: driver}} = conn, _params) do
    missed_matches = Drivers.list_missed_matches_for_driver(driver)

    conn
    |> render_version("index.json", matches: missed_matches)
  end

  def show(%{assigns: %{match: match}} = conn, _params) do
    render_version(conn, "show.json", driver_match: match)
  end

  def live(%{assigns: %{current_driver: driver}} = conn, _params) do
    live_matches = Drivers.list_live_matches_for_driver(driver)

    conn
    |> render_version("index.json", matches: live_matches)
  end

  def completed(%{assigns: %{current_driver: _driver}} = conn, %{
        "cursor" => page,
        "per_page" => per_page
      })
      when not is_integer(page) do
    page_number = page |> String.to_integer()
    completed(conn, %{"cursor" => page_number, "per_page" => per_page})
  end

  def completed(%{assigns: %{current_driver: _driver}} = conn, %{
        "cursor" => page,
        "per_page" => per_page
      })
      when not is_integer(per_page) do
    per_page_number = per_page |> String.to_integer()
    completed(conn, %{"cursor" => page, "per_page" => per_page_number})
  end

  def completed(%{assigns: %{current_driver: driver}} = conn, %{
        "cursor" => page,
        "per_page" => per_page
      }) do
    with {:ok, %{completed_matches: matches, total_pages: total_pages}} <-
           Drivers.list_completed_matches_for_driver(driver, page, per_page) do
      conn
      |> render_version("index.json", matches: matches, total_pages: total_pages)
    end
  end

  def completed(
        %{assigns: %{current_driver: _driver}} = conn,
        %{"cursor" => _cursor} = pagination
      )
      when is_map(pagination) do
    completed(conn, Map.put(pagination, "per_page", 10))
  end

  def update(
        %{assigns: %{match: match, current_driver: driver}} = conn,
        %{
          "state" => "accepted"
        }
      ) do
    with {:ok, match} <- Drivers.accept_match(match, driver) do
      render_version(conn, "show.json", driver_match: match)
    end
  end

  def update(
        %{assigns: %{match: match, current_driver: driver}} = conn,
        %{
          "state" => "rejected"
        }
      ) do
    with {:ok, _hidden_match} <- Drivers.reject_match(match, driver) do
      send_resp(conn, :no_content, "")
    end
  end

  def update(%{assigns: %{match: match}} = conn, %{"state" => "arrived_at_pickup"} = attrs) do
    parking_spot = Map.get(attrs, "parking_spot")

    with {:ok, updated_match} <- Drivers.arrived_at_pickup(match, parking_spot) do
      render_version(conn, "show.json", driver_match: updated_match)
    end
  end

  def update(%{assigns: %{match: match}} = conn, %{"state" => "picked_up"} = params) do
    with {:ok, origin_image} <- file_from_params(params, "origin_photo"),
         {:ok, bill_of_lading_image} <- file_from_params(params, "bill_of_lading_photo"),
         {:ok, match} <-
           Drivers.picked_up(
             match,
             %{
               origin_photo: origin_image,
               bill_of_lading_photo: bill_of_lading_image
             }
           ) do
      render_version(conn, "show.json", driver_match: match)
    end
  end

  def update(%{assigns: %{match: match}} = conn, %{
        "state" => "cancel",
        "reason" => reason
      }) do
    with {:ok, match} <- Drivers.cancel_match(match, reason) do
      render_version(conn, "show.json", driver_match: match)
    end
  end

  def update(%{assigns: %{match: match, driver_location: driver_location}} = conn, %{
        "state" => "unable_to_pickup",
        "reason" => reason
      }) do
    with {:ok, updated_match} <- Drivers.unable_to_pickup_match(match, reason, driver_location) do
      render_version(conn, "show.json", driver_match: updated_match)
    end
  end

  def update(%{assigns: %{match: match}} = conn, %{"state" => "arrived_at_return"} = attrs) do
    parking_spot = Map.get(attrs, "parking_spot")

    with {:ok, match} <- Drivers.arrived_at_return(match, parking_spot) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match)
    end
  end

  def update(%{assigns: %{match: match}} = conn, %{"state" => "returned"}) do
    with {:ok, match} <- MatchWorkflow.complete_match(match) do
      conn
      |> put_view(FraytElixirWeb.Internal.V2x1.DriverMatchView)
      |> render("show.json", driver_match: match)
    end
  end

  def toggle_en_route(%{assigns: %{match: match}} = conn, _) do
    with {:ok, match} <- Drivers.toggle_en_route(match) do
      render_version(conn, "show.json", driver_match: match)
    end
  end

  defp render_version(%{assigns: %{version: version}} = conn, file, args) do
    view =
      case version do
        :V2x1 -> FraytElixirWeb.Internal.V2x1.DriverMatchView
        :v2 -> FraytElixirWeb.Internal.V2x1.DriverMatchView
      end

    conn
    |> put_view(view)
    |> render(file, args)
  end

  defp file_from_params(params, name) do
    case Map.get(params, name) do
      %{"contents" => contents, "filename" => filename} ->
        UploadHelper.file_from_base64(contents, filename, name)

      _ ->
        {:ok, nil}
    end
  end
end
