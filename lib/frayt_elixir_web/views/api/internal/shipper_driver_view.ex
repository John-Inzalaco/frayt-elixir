defmodule FraytElixirWeb.API.Internal.ShipperDriverView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.DriverView

  def render("index.json", %{drivers: drivers}) do
    %{data: render_many(drivers, DriverView, "driver.json")}
  end
end
