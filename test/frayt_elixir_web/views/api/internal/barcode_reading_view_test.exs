defmodule FraytElixirWeb.API.Internal.BarcodeReadingViewTest do
  use FraytElixirWeb.ConnCase, async: true

  alias FraytElixirWeb.API.Internal.BarcodeReadingView
  alias FraytElixir.Shipment.BarcodeReading

  import FraytElixir.Factory

  test "render barcode_reading" do
    %BarcodeReading{
      type: type,
      state: state,
      photo: photo,
      barcode: barcode,
      inserted_at: inserted_at,
      match_stop_item_id: item_id
    } = barcode_reading = insert(:barcode_reading)

    rendered_item =
      BarcodeReadingView.render("barcode_reading.json", %{barcode_reading: barcode_reading})

    assert %{
             "type" => type,
             "state" => state,
             "photo" => photo,
             "barcode" => barcode,
             "inserted_at" => inserted_at,
             "item_id" => item_id
           } == rendered_item
  end
end
