defmodule FraytElixirWeb.API.Internal.MarketView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.MarketView

  def render("shipper_market.json", %{
        market: %{
          has_box_trucks: has_box_trucks
        }
      }),
      do: %{
        has_box_trucks: has_box_trucks
      }

  def render("market.json", %{market: market}) do
    %{
      id: market.id,
      region: market.region,
      name: market.name,
      currently_hiring: market.currently_hiring
    }
  end

  def render("index.json", %{markets: markets}) do
    %{response: render_many(markets, MarketView, "market.json")}
  end
end
