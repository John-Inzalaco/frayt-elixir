defmodule FraytElixirWeb.Admin.DriversLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/drivers",
    default_filters: %{order_by: :updated_at},
    filters: [
      %{key: :vehicle_class, type: :integer, default: nil},
      %{key: :query, type: :string, default: nil},
      %{key: :state, type: :atom, default: :active},
      %{key: :document_state, type: :atom, default: nil}
    ],
    model: :drivers

  use FraytElixirWeb.ModalEvents
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  alias FraytElixir.Drivers

  def mount(_params, _session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      {:ok,
       assign(socket, %{
         live_view: nil,
         title: nil,
         show_modal: false
       })}
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("index.html", assigns)
  end

  def list_records(socket, filters), do: {socket, Drivers.list_drivers(filters)}
end
