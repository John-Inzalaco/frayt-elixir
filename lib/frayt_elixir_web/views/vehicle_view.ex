defmodule FraytElixirWeb.VehicleView do
  use FraytElixirWeb, :view

  def render("vehicle.json", %{vehicle: vehicle}) do
    %{
      id: vehicle.id,
      vehicle_make: vehicle.make,
      vehicle_model: vehicle.model,
      vehicle_year: vehicle.year,
      vehicle_class: vehicle.vehicle_class
    }
  end
end
