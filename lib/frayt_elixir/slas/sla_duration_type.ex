defmodule FraytElixir.SLAs.SLADurationType do
  @types [
    :duration_before_time,
    :end_time
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
