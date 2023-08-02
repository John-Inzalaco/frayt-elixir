defmodule FraytElixir.Accounts.APIVersion do
  @types [
    :"2.0",
    :"2.1"
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
