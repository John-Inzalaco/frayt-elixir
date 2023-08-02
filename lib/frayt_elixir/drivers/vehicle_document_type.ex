defmodule FraytElixir.Drivers.VehicleDocumentType do
  @types [
    :passengers_side,
    :drivers_side,
    :cargo_area,
    :front,
    :registration,
    :insurance,
    :back,
    :vehicle_type,
    :carrier_agreement
  ]

  use FraytElixir.Type.Enum, types: @types
end
