defmodule FraytElixir.Shipment.MatchStopSignatureType do
  @types [
    :photo,
    :electronic
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
