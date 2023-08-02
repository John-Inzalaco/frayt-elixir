defmodule FraytElixirWeb.MatchStopItemViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.MatchStopItemView
  alias FraytElixir.Shipment.MatchStopItem
  import FraytElixir.Factory

  test "render match_stop_item" do
    %MatchStopItem{
      width: width,
      height: height,
      weight: weight,
      length: length,
      pieces: pieces,
      volume: volume,
      description: description,
      type: type
    } = match_stop_item = insert(:match_stop_item)

    rendered_item =
      MatchStopItemView.render("match_stop_item.json", %{match_stop_item: match_stop_item})

    assert %{
             "length" => ^length,
             "width" => ^width,
             "height" => ^height,
             "weight" => ^weight,
             "pieces" => ^pieces,
             "volume" => ^volume,
             "description" => ^description,
             "type" => ^type
           } = rendered_item
  end

  test "render matches" do
    [%MatchStopItem{description: description} | _] =
      match_stop_items = insert_list(3, :match_stop_item)

    rendered_items = MatchStopItemView.render("index.json", %{match_stop_items: match_stop_items})
    assert %{response: [rendered_item | _]} = rendered_items
    assert %{"description" => ^description} = rendered_item
  end

  test "render show match" do
    %MatchStopItem{description: description} = match_stop_item = insert(:match_stop_item)

    assert %{response: rendered_item} =
             MatchStopItemView.render("show.json", %{match_stop_item: match_stop_item})

    assert rendered_item["description"] == description
  end
end
