defmodule FraytElixir.Accounts.UserType do
  @types [
    :shipper,
    :driver,
    :admin
  ]

  use FraytElixir.Type.Enum,
    types: @types
end
