defmodule FraytElixirWeb.Admin.BatchesView do
  use FraytElixirWeb, :view

  import FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.BatchState

  def find_transition(batch, state, order \\ :desc) do
    Shipment.find_transition(batch, state, order)
  end
end
