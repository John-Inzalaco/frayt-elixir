defmodule FraytElixir.Vehicle.VehicleType do
  @types [
    :car,
    :midsize,
    :cargo_van,
    :box_truck
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
