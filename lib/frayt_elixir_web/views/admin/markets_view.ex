defmodule FraytElixirWeb.Admin.MarketsView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  import FraytElixirWeb.DisplayFunctions
  import FraytElixirWeb.Admin.AddressesView, only: [state_code_options: 0]
  alias FraytElixir.Vehicle.VehicleType
  alias FraytElixir.Convert

  def to_minutes(seconds) do
    seconds
    |> Convert.to_integer(0)
    |> Kernel./(60)
    |> round()
  end

  def error_class(changeset, field),
    do: if(changeset.action, do: input_error(changeset.errors, field), else: "")
end
