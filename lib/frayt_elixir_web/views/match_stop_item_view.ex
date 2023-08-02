defmodule FraytElixirWeb.MatchStopItemView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.MatchStopItemView
  alias FraytElixir.Shipment.MatchStopItem
  alias FraytElixirWeb.API.Internal.BarcodeReadingView
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Repo

  def render("index.json", %{match_stop_items: match_stop_items}) do
    %{
      response: render_many(match_stop_items, MatchStopItemView, "match_stop_item.json")
    }
  end

  def render("show.json", %{match_stop_item: match_stop_item}) do
    %{response: render_one(match_stop_item, MatchStopItemView, "match_stop_item.json")}
  end

  def render("match_stop_item.json", %{
        match_stop_item: %MatchStopItem{barcode_readings: %NotLoaded{}} = msi
      }) do
    match_stop_item = msi |> Repo.preload([:barcode_readings])
    render("match_stop_item.json", %{match_stop_item: match_stop_item})
  end

  def render("match_stop_item.json", %{
        match_stop_item: %MatchStopItem{
          id: id,
          height: height,
          length: length,
          pieces: pieces,
          volume: volume,
          weight: weight,
          width: width,
          description: description,
          type: type,
          declared_value: declared_value,
          barcode_readings: barcode_readings,
          barcode: barcode,
          barcode_delivery_required: barcode_delivery_required,
          barcode_pickup_required: barcode_pickup_required
        }
      }) do
    %{
      "id" => id,
      "height" => height,
      "length" => length,
      "pieces" => pieces,
      "volume" => volume,
      "weight" => weight,
      "width" => width,
      "description" => description,
      "type" => type,
      "barcode" => barcode,
      "barcode_readings" =>
        render_many(barcode_readings, BarcodeReadingView, "barcode_reading.json"),
      "barcode_delivery_required" => barcode_delivery_required,
      "barcode_pickup_required" => barcode_pickup_required,
      "declared_value" => declared_value
    }
  end
end
