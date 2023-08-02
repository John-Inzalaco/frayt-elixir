defmodule FraytElixir.SLAs.SLAType do
  @types [
    :acceptance,
    :pickup,
    :delivery
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
