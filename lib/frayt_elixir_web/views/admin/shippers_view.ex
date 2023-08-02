defmodule FraytElixirWeb.Admin.ShippersView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  import FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Accounts.{Company, ShipperRole, AdminUser, ShipperState}
end
