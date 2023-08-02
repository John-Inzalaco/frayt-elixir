defmodule FraytElixirWeb.Admin.BatchesLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    model: :batches,
    base_url: "/admin/batches",
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :state, type: :atom, default: :routing}
    ]

  alias FraytElixir.Shipment.DeliveryBatches

  def mount(_, _, socket), do: {:ok, socket}

  def list_records(socket, filters), do: {socket, DeliveryBatches.list_batches(filters)}

  def render(assigns) do
    FraytElixirWeb.Admin.BatchesView.render("index.html", assigns)
  end
end
