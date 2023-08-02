defmodule FraytElixirWeb.API.Internal.DriverDocumentView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions

  alias FraytElixir.Drivers.{DriverDocument, VehicleDocument}

  def render("driver_document.json", %{id: nil}), do: nil

  def render("driver_document.json", %{driver_document: %VehicleDocument{} = driver_document}) do
    %{
      id: driver_document.id,
      document: get_photo_url(driver_document.vehicle_id, driver_document.document),
      expires_at: driver_document.expires_at,
      notes: driver_document.notes,
      state: driver_document.state,
      type: driver_document.type
    }
  end

  def render("driver_document.json", %{driver_document: %DriverDocument{} = driver_document}) do
    %{
      id: driver_document.id,
      document: get_photo_url(driver_document.driver_id, driver_document.document),
      expires_at: driver_document.expires_at,
      notes: driver_document.notes,
      state: driver_document.state,
      type: driver_document.type
    }
  end
end
