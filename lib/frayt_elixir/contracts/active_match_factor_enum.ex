defmodule FraytElixir.Contracts.ActiveMatchFactor do
  @factors [
    :delivery_duration,
    :fixed_duration
  ]

  use FraytElixir.Type.Enum, types: @factors
end
