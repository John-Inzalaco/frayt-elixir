defmodule FraytElixirWeb.AddressView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.AddressView
  alias FraytElixir.Shipment.Address

  def render("index.json", %{addresses: addresses}) do
    %{response: render_many(addresses, AddressView, "address.json")}
  end

  def render("show.json", %{address: address}) do
    %{response: render_one(address, AddressView, "address.json")}
  end

  def render("address.json", %{
        address:
          %Address{
            geo_location: %Geo.Point{
              coordinates: {lng, lat}
            }
          } = address
      }) do
    %{
      formatted_address: address.formatted_address,
      lat: lat,
      lng: lng,
      address: address.address,
      address2: address.address2,
      city: address.city,
      state: address.state,
      state_code: address.state_code,
      zip: address.zip,
      country: address.country,
      neighborhood: address.neighborhood,
      name: address.name,
      country_code: address.country_code
    }
  end

  def render("address.json", %{address: %Address{} = address}) do
    %{
      formatted_address: address.formatted_address,
      address: address.address,
      lat: nil,
      lng: nil,
      address2: address.address2,
      city: address.city,
      state: address.state,
      state_code: address.state_code,
      zip: address.zip,
      country: address.country,
      neighborhood: address.neighborhood
    }
  end

  def render("address.json", %{address: address}), do: %{address: address}
end
