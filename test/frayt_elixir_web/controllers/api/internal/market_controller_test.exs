defmodule FraytElixirWeb.API.Internal.MarketControllerTest do
  use FraytElixirWeb.ConnCase
  import FraytElixir.Factory

  describe "index" do
    test "lists all hiring markets", %{conn: conn} do
      insert_list(2, :market, currently_hiring: [:car, :box_truck])
      insert_list(2, :market, currently_hiring: [])
      conn = get(conn, Routes.api_v2_market_path(conn, :index, ".1"))

      assert %{"response" => [%{"id" => _}, %{"id" => _}]} = json_response(conn, 200)
    end
  end
end
