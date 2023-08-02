defmodule FraytElixir.Accounts.AdminRole do
  @types [:admin, :network_operator, :member, :sales_rep, :developer, :driver_services]

  use FraytElixir.Type.Enum,
    types: @types
end
