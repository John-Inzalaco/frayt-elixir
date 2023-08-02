defmodule FraytElixirWeb.Admin.ApplicantsLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/drivers/applicants",
    default_filters: %{order_by: :updated_at},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :vehicle_class, type: :integer, default: nil},
      %{key: :state, type: :atom, default: :all_applicants},
      %{key: :market_id, type: :atom, default: nil},
      %{key: :document_state, type: :atom, default: nil, if: {:state, :pending_approval}},
      %{
        key: :background_check_state,
        type: :string,
        default: nil,
        if: {:state, :screening}
      }
    ],
    model: :drivers

  use FraytElixirWeb.ModalEvents
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  alias FraytElixir.Drivers
  alias FraytElixir.DriverDocuments

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
    FraytElixirWeb.Admin.DriversView.render("applicants.html", assigns)
  end

  def handle_event("handle_submit", _, socket),
    do: {:noreply, socket}

  def list_records(socket, filters),
    do:
      {socket,
       Drivers.list_drivers(filters, [
         :user,
         :background_check,
         :market,
         :state_transitions,
         images: DriverDocuments.latest_driver_documents_query(),
         vehicles: [images: DriverDocuments.latest_vehicle_documents_query()]
       ])}
end
