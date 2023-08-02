defmodule FraytElixirWeb.API.Internal.BarcodeReadingView do
  use FraytElixirWeb, :view

  import FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Shipment.BarcodeReading

  def render("barcode_reading.json", %{
        barcode_reading: %BarcodeReading{
          id: id,
          type: type,
          state: state,
          photo: photo,
          barcode: barcode,
          inserted_at: inserted_at,
          match_stop_item_id: item_id
        }
      }) do
    %{
      "type" => type,
      "state" => state,
      "photo" => fetch_photo_url(id, photo),
      "barcode" => barcode,
      "inserted_at" => inserted_at,
      "item_id" => item_id
    }
  end
end
