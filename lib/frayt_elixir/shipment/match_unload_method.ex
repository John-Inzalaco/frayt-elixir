defmodule FraytElixir.Shipment.MatchUnloadMethod do
  @types [
    :dock_to_dock,
    :lift_gate
  ]
  use FraytElixir.Type.Enum, types: @types
end
