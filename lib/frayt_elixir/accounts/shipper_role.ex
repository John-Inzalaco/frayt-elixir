defmodule FraytElixir.Accounts.ShipperRole do
  @types [:company_admin, :location_admin, :member]

  use FraytElixir.Type.Enum,
    types: @types
end
