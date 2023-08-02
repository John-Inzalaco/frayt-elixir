defmodule FraytElixir.Shipment.AddressTest do
  use FraytElixir.DataCase
  alias FraytElixir.Shipment.Address

  test "from_geocoding/1 gets a lat, lng, and formatted address" do
    assert %{
             geo_location: %Geo.Point{coordinates: {lng, lat}},
             formatted_address: formatted_address,
             address: address,
             state: state,
             state_code: state_code,
             county: county,
             country: country,
             country_code: country_code,
             address2: address2
           } = Address.from_geocoding("708 Walnut St, Cincinnati, OH 45202")

    assert lat == 39.1043198
    assert lng == -84.5118912
    assert address == "708 Walnut Street"
    assert county == "Hamilton County"
    assert state == "Ohio"
    assert state_code == "OH"
    assert address2 == "500"
    assert country == "United States"
    assert country_code == "US"
    assert formatted_address == "708 Walnut St, Cincinnati, OH 45202"
  end

  test "from_geocoding/1 with garbage in antartica finds the garbage in antartica" do
    assert %{geo_location: %Geo.Point{}} = Address.from_geocoding("garbage, antartica")
  end

  test "from_geocoding/1 with total garbage" do
    assert %{address: %{error: "Address is invalid"}} = Address.from_geocoding("garbage")

    changeset_result =
      Address.geocoding_changeset(
        %Address{},
        %{city: "", state: "", zip: "", address: "garbage"}
      )

    refute changeset_result.valid?
  end
end
