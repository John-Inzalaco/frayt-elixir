defmodule FraytElixir.MarketsTest do
  use FraytElixir.DataCase
  alias FraytElixir.Markets
  alias FraytElixir.Markets.Market

  describe "markets" do
    test "delete a market" do
      market = insert(:market)
      Markets.delete_market(market)
      refute Repo.get(Market, market.id)
    end

    test "find a market by zip code when zip code exists" do
      insert(:market)
      %{id: market_id} = insert(:market, zip_codes: [insert(:market_zip_code, zip: "12345")])
      insert(:market)
      assert %Market{id: ^market_id} = Markets.find_market_by_zip("12345")
    end

    test "market by zip code return nil for nonexistent zip" do
      assert Markets.find_market_by_zip("12345") == nil
    end

    test "market by zip code return nil for nil" do
      assert Markets.find_market_by_zip(nil) == nil
    end

    test "checks if market has box truck" do
      %{id: market_id} = market = insert(:market, has_box_trucks: true)

      assert Markets.market_has_boxtrucks?(market_id) == true
      assert Markets.market_has_boxtrucks?(market) == true
    end

    test "checks if market has box truck is false for no market" do
      assert Markets.market_has_boxtrucks?(nil) == false
    end
  end

  describe "list_markets/1" do
    test "lists all markets" do
      insert_list(6, :market)
      assert {markets, 1} = Markets.list_markets()

      assert length(markets) == 6
    end

    test "filters by query" do
      insert_list(6, :market, name: "ABC")
      insert(:market, name: "DEF", zip_codes: [build(:market_zip_code, zip: "12345")])
      insert(:market, name: "GHI", zip_codes: [build(:market_zip_code, zip: "123")])

      insert(:market,
        name: "GHI",
        zip_codes: [build(:market_zip_code, zip: "43123"), build(:market_zip_code, zip: "11234")]
      )

      assert {[%Market{}], 1} = Markets.list_markets(%{query: "DE"})
      assert {[%Market{}, %Market{}, %Market{}], 1} = Markets.list_markets(%{query: "123"})
    end

    test "filters by hiring" do
      insert_list(2, :market, currently_hiring: [:midsize])
      insert_list(3, :market, currently_hiring: [:car, :box_truck])
      insert_list(4, :market, currently_hiring: [])
      assert {markets, 1} = Markets.list_markets(%{currently_hiring: true})

      assert length(markets) == 5
    end
  end
end
