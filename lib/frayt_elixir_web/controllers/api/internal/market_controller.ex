defmodule FraytElixirWeb.API.Internal.MarketController do
  use FraytElixirWeb, :controller
  alias FraytElixir.Markets

  action_fallback(FraytElixirWeb.FallbackController)

  def index(conn, _params) do
    {markets, 1} = Markets.list_markets(%{per_page: 1000, currently_hiring: true})

    render(conn, "index.json", markets: markets)
  end
end
