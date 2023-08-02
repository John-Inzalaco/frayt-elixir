defmodule FraytElixirWeb.LocationView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.LocationView
  alias FraytElixir.Accounts.Location
  alias FraytElixir.Shipment.Address
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Repo

  def render("show.json", %{location: location}) do
    %{response: render_one(location, LocationView, "location.json")}
  end

  def render("location.json", %{location: nil}), do: nil

  def render("location.json", %{location: %Location{company: %NotLoaded{}} = location}) do
    location = location |> Repo.preload([:address, :company])
    render("location.json", %{location: location})
  end

  def render("location.json", %{location: %Location{address: %NotLoaded{}} = location}) do
    location = location |> Repo.preload([:address, :company])
    render("location.json", %{location: location})
  end

  def render("location.json", %{
        location: %Location{
          id: id,
          location: location_name,
          address: %Address{
            address: address,
            address2: address2,
            neighborhood: neighborhood,
            city: city,
            county: county,
            state_code: state
          }
        }
      }) do
    %{
      id: id,
      name: location_name,
      address: address,
      address2: address2,
      neighborhood: neighborhood,
      city: city,
      county: county,
      state: state
    }
  end
end
