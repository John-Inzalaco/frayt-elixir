defmodule FraytElixirWeb.VehicleDocumentView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions

  def render("vehicle_document.json", %{vehicle_document: nil}), do: nil

  def render("vehicle_document.json", %{vehicle_document: vehicle_document}) do
    %{
      id: vehicle_document.id,
      document: get_photo_url(vehicle_document.vehicle_id, vehicle_document.document),
      expires_at: vehicle_document.expires_at,
      notes: vehicle_document.notes,
      state: vehicle_document.state,
      type: vehicle_document.type
    }
  end
end
