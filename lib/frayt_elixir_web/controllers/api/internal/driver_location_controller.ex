defmodule FraytElixirWeb.API.Internal.DriverLocationController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver

  import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]

  plug :authorize_driver

  action_fallback FraytElixirWeb.FallbackController

  def create(%{assigns: %{current_driver: driver}} = conn, %{
        "latitude" => latitude,
        "longitude" => longitude
      }) do
    with {:ok, %Driver{current_location: driver_location}} <-
           Drivers.update_current_location(driver, %Geo.Point{coordinates: {longitude, latitude}}) do
      conn
      |> put_status(:created)
      |> render("show.json", driver_location: driver_location)
    end
  end
end
