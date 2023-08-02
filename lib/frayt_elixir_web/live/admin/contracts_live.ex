defmodule FraytElixirWeb.Admin.ContractsLive do
  use Phoenix.LiveView

  use FraytElixirWeb.DataTable,
    base_url: "/admin/settings/contracts",
    default_filters: %{order_by: :updated_at},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :company_id, type: :string, default: nil}
    ],
    model: :contracts,
    handle_params: :root

  alias FraytElixir.Contracts

  def mount(_params, %{"time_zone" => time_zone, "current_user" => current_user}, socket) do
    {:ok,
     assign(
       socket,
       %{
         time_zone: time_zone,
         current_user: current_user
       }
     )}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ContractsView.render("index.html", assigns)
  end

  def list_records(socket, filters), do: {socket, Contracts.list_contracts(filters)}
end
