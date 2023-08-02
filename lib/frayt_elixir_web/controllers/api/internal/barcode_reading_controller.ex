defmodule FraytElixirWeb.API.Internal.BarcodeReadingController do
  use FraytElixirWeb, :controller
  import FraytElixir.AtomizeKeys

  import FraytElixirWeb.SessionHelper,
    only: [
      authorize_driver: 2,
      authorize_driver_match: 2,
      authorize_driver_match_stop: 2,
      authorize_driver_match_stop_item: 2
    ]

  alias FraytElixir.Shipment.BarcodeReadings

  plug :authorize_driver
  plug :authorize_driver_match
  plug :authorize_driver_match_stop
  plug :authorize_driver_match_stop_item

  action_fallback FraytElixirWeb.FallbackController

  def create(%{assigns: %{match_stop_item: item}} = conn, params) do
    params =
      params
      |> Map.take(["barcode", "type", "state", "photo"])
      |> atomize_keys()

    with {:ok, reading} <- BarcodeReadings.create(item, params) do
      conn
      |> put_status(:created)
      |> render("barcode_reading.json", barcode_reading: reading)
    end
  end
end
