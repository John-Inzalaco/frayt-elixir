defmodule FraytElixir.Accounts.ShipperState do
  @types [:disabled, :approved, :pending_approval]

  use FraytElixir.Type.Enum,
    types: @types
end
