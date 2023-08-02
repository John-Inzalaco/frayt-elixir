defmodule FraytElixirWeb.API.Internal.VehicleView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.VehicleView
  alias FraytElixirWeb.API.Internal.DriverDocumentView

  def render("show.json", %{vehicle: vehicle}) do
    %{response: render_one(vehicle, VehicleView, "vehicle.json")}
  end

  def render("vehicle.json", nil), do: nil

  def render("vehicle.json", %{vehicle: vehicle}) do
    images = if Ecto.assoc_loaded?(vehicle.images), do: Map.get(vehicle, :images), else: []

    FraytElixirWeb.VehicleView.render("vehicle.json", %{vehicle: vehicle})
    |> Map.merge(%{
      capacity_dismissed_at: convert_updated_at(vehicle.updated_at),
      capacity_height: vehicle.cargo_area_height,
      capacity_width: vehicle.cargo_area_width,
      capacity_length: vehicle.cargo_area_length,
      capacity_weight: vehicle.max_cargo_weight,
      capacity_door_height: vehicle.door_height,
      capacity_door_width: vehicle.door_width,
      capacity_between_wheel_wells: vehicle.wheel_well_width,
      license_plate: vehicle.license_plate,
      lift_gate: vehicle.lift_gate,
      pallet_jack: vehicle.pallet_jack,
      images: render_many(images, DriverDocumentView, "driver_document.json")
    })
  end

  defp convert_updated_at(nil), do: nil

  defp convert_updated_at(updated_at),
    do: updated_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:millisecond)
end
