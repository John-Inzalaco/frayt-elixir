defmodule FraytElixirWeb.DriverLocationView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.DriverLocationView

  def render("index.json", %{driver_locations: driver_locations}) do
    %{data: render_many(driver_locations, DriverLocationView, "driver_location.json")}
  end

  def render("show.json", %{driver_location: driver_location}) do
    %{response: render_one(driver_location, DriverLocationView, "driver_location.json")}
  end

  def render("driver_location.json", %{
        driver_location: %{
          id: id,
          geo_location: %Geo.Point{coordinates: {lng, lat}},
          inserted_at: inserted_at
        }
      }) do
    %{id: id, lat: lat, lng: lng, created_at: inserted_at}
  end

  def render("driver_location.json", nil), do: nil
end
