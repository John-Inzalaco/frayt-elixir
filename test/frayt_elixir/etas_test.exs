defmodule FraytElixir.ETAPollerTest do
  use FraytElixir.DataCase
  use Bamboo.Test

  alias FraytElixir.{Routing, Routing.ETA}

  @interval 30 * 1000

  @coord_a {1, 2}
  @coord_b {3, 4}
  @route_a_to_b [{2, 1}, {4, 3}]
  @location_a build(:driver_location, geo_location: %Geo.Point{coordinates: @coord_a})
  @address_b build(:address, geo_location: %Geo.Point{coordinates: @coord_b})
  @driver_a build(:driver, current_location: @location_a)
  @eta build(:eta, updated_at: NaiveDateTime.utc_now(), match: nil)
  @match_stops_b [
    build(:match_stop, state: :en_route, destination_address: @address_b, eta: @eta)
  ]

  describe "split_matches_with_new_locations" do
    test "splits matches with new locations from old locations" do
      relocated_driver =
        insert(:match,
          driver: insert(:driver, current_location_inserted_at: NaiveDateTime.utc_now()),
          state: :en_route_to_pickup,
          eta: %{
            @eta
            | updated_at:
                NaiveDateTime.utc_now() |> NaiveDateTime.add(-(@interval + 5000), :millisecond)
          }
        )

      static_driver =
        insert(:match,
          driver:
            insert(:driver,
              current_location_inserted_at:
                NaiveDateTime.utc_now()
                |> NaiveDateTime.add(
                  -(@interval + 5000),
                  :millisecond
                )
            ),
          state: :en_route_to_pickup,
          eta: %{
            @eta
            | updated_at:
                NaiveDateTime.utc_now() |> NaiveDateTime.add(-(@interval + 5000), :millisecond)
          }
        )

      [{_, relocated_matches}, {_, static_matches}] =
        ETA.split_matches_with_new_locations([static_driver, relocated_driver])

      assert Enum.count(relocated_matches) == 1
      assert Enum.count(static_matches) == 1
    end
  end

  describe "get_route" do
    test "uses match origin as destination when status is en route" do
      match =
        build(:match, state: :en_route_to_pickup, origin_address: @address_b, driver: @driver_a)

      assert {:ok, @route_a_to_b, :match_origin_addr, match} ==
               Routing.get_route(match)

      match =
        build(:match, state: :en_route_to_return, origin_address: @address_b, driver: @driver_a)

      assert {:ok, @route_a_to_b, :match_origin_addr, match} ==
               Routing.get_route(match)

      assert {:ok, @route_a_to_b, :match_origin_addr, match} !=
               Routing.get_route(build(:match))
    end

    test "uses destination address from last en route match stop when status is picked up" do
      match = build(:match, state: :picked_up, match_stops: @match_stops_b, driver: @driver_a)

      assert {:ok, @route_a_to_b, :match_stop_dest_addr, match} ==
               Routing.get_route(match)
    end
  end

  describe "get_routes" do
    test "returns buckets for routed and failed matches" do
      matches = [
        build(:match, state: :en_route_to_pickup, origin_address: @address_b, driver: @driver_a),
        build(:match, state: :en_route_to_dropoff, origin_address: @address_b, driver: @driver_a),
        build(:match, state: :picked_up, match_stops: @match_stops_b, driver: @driver_a),
        build(:match, state: :accepted)
      ]

      [{:routes, routes}, {:failed, failed}] = Routing.get_routes(matches)
      assert Enum.count(routes) == 2
      assert Enum.count(failed) == 2
    end
  end

  describe "build_eta_attrs" do
    test "returns a stop eta for a match with active stops" do
      %{match_stops: [stop]} =
        match =
        insert(:match,
          state: :picked_up,
          match_stops: @match_stops_b,
          driver: @driver_a,
          eta: @eta
        )

      {:ok, eta} = ETA.build_eta_attrs(match, NaiveDateTime.utc_now())
      FraytElixir.Shipment.get_match(match)

      assert eta.stop_id == stop.id
      refute Map.has_key?(eta, :match_id)
    end

    test "returns a match eta for a match in en_route_to_pickup without active stops" do
      match =
        insert(:match,
          state: :en_route_to_pickup,
          origin_address: @address_b,
          driver: @driver_a,
          eta: @eta
        )

      {:ok, eta} = ETA.build_eta_attrs(match, NaiveDateTime.utc_now())

      assert eta.match_id == match.id
      refute Map.has_key?(eta, :stop_id)
    end
  end
end
