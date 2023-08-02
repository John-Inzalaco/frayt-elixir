defmodule FraytElixirWeb.Admin.CompaniesLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/companies",
    default_filters: %{order_by: :revenue, per_page: 10},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :sales_rep_id, type: :string, default: nil}
    ],
    model: :companies

  use FraytElixirWeb.ModalEvents
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  alias FraytElixir.Accounts

  def mount(_params, _session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      {:ok,
       assign(
         socket,
         %{
           show_modal: false,
           errors: [],
           edit_form: %{},
           default_form: :company,
           chosen_company: nil,
           chosen_company_name: nil,
           chosen_location: nil,
           title: "Create Company",
           attrs: nil
         }
       )}
    end)
  end

  def handle_event("add_company", _event, socket) do
    live_view_action(__MODULE__, "add_company", socket, fn ->
      {:noreply,
       assign(open_modal(socket), %{
         default_form: :company,
         chosen_company: nil,
         chosen_company_name: nil,
         title: "Create Company"
       })}
    end)
  end

  def handle_info({:to_add_shippers, attrs, chosen_company_id, chosen_company_name}, socket) do
    live_view_action(__MODULE__, "to_add_shippers", socket, fn ->
      {:noreply,
       assign(socket, %{
         show_modal: true,
         chosen_company: chosen_company_id,
         chosen_company_name: chosen_company_name,
         attrs: attrs,
         title: "Add Shippers",
         default_form: :shipper
       })}
    end)
  end

  def handle_info(:new_shipper_added, socket) do
    live_view_action(__MODULE__, "new_shipper_added", socket, fn ->
      socket = update_results(socket)

      {:noreply,
       assign(socket, %{
         show_modal: false,
         chosen_location: nil,
         chosen_company: nil
       })}
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("index.html", assigns)
  end

  def list_records(socket, filters), do: {socket, Accounts.list_companies(filters)}
end
