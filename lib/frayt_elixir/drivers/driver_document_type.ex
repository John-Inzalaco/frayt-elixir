defmodule FraytElixir.Drivers.DriverDocumentType do
  @types [
    :license,
    :profile
  ]

  use FraytElixir.Type.Enum, types: @types
end
