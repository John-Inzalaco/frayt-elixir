defmodule FraytElixirWeb.API.Internal.DriverDocumentController do
  use FraytElixirWeb, :controller

  import FraytElixir.AtomizeKeys
  # import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]
  alias Ecto.UUID
  alias FraytElixir.Drivers
  alias FraytElixir.DriverDocuments
  alias FraytElixir.Drivers.DriverDocumentType
  alias FraytElixirWeb.UploadHelper

  # plug :authorize_driver

  action_fallback(FraytElixirWeb.FallbackController)

  def profile_photo(conn, %{"driver_id" => id}) do
    driver = Drivers.get_driver!(id)

    case DriverDocuments.get_s3_asset(:profile_photo, driver) do
      {:ok, url} -> redirect(conn, external: url)
      {:error, _error} -> send_resp(conn, 404, "")
    end
  end

  def update_photo(conn, %{"driver_id" => driver_id, "photo" => params}) do
    %{vehicles: [vehicle | _]} = driver = Drivers.get_driver!(driver_id)

    %{type: type, document: photo, expiration_date: expires_at} =
      params
      |> Map.take(["document", "type", "expiration_date"])
      |> atomize_keys()

    UploadHelper.file_from_base64(photo, "license.jpg", "#{UUID.generate()}-license")

    with {:ok, photo} <-
           UploadHelper.file_from_base64(photo, "license.jpg", "#{UUID.generate()}-license"),
         {:ok, driver_document} <- create_document(type, photo, driver, vehicle, expires_at) do
      conn
      |> put_status(:created)
      |> render("driver_document.json", driver_document: driver_document)
    end
  end

  defp create_document(type, document, driver, vehicle, expires_at) do
    if type in DriverDocumentType.all_types(string?: true) do
      DriverDocuments.create_driver_document(%{
        type: type,
        state: :pending_approval,
        expires_at: expires_at,
        document: document,
        driver_id: driver.id
      })
    else
      DriverDocuments.create_vehicle_document(%{
        type: type,
        state: :pending_approval,
        expires_at: expires_at,
        document: document,
        vehicle_id: vehicle.id
      })
    end
  end
end
