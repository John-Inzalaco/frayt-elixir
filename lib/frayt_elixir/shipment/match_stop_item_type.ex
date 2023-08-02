defmodule FraytElixir.Shipment.MatchStopItemType do
  @types [
    :item,
    :pallet,
    :lumber,
    :sheet_rock
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
