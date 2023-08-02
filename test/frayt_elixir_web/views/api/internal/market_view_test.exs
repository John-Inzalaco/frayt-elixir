defmodule FraytElixirWeb.API.Internal.MarketViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.API.Internal.MarketView

  import FraytElixir.Factory

  test "rendered shipper market returns correct values" do
    market = insert(:market, has_box_trucks: true)

    assert %{
             has_box_trucks: true
           } = MarketView.render("shipper_market.json", %{market: market})
  end

  test "rendered market returns correct values" do
    market = insert(:market)

    assert result = MarketView.render("market.json", %{market: market})

    assert result.region == market.region
    assert result.id == market.id
    assert result.name == market.name
  end
end
