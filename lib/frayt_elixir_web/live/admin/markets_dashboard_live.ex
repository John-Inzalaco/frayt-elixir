defmodule FraytElixirWeb.Admin.MarketsDashboardLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/markets/dashboard",
    default_filters: %{order_by: :updated_at},
    filters: [%{key: :query, type: :string, default: nil}],
    model: :markets

  use FraytElixirWeb.ModalEvents

  alias FraytElixir.Markets

  def mount(_params, _session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      {:ok,
       assign(socket, %{
         live_view: nil,
         title: nil,
         show_modal: false,
         edit_market: nil
       })}
    end)
  end

  def handle_event("edit_market_" <> market_id, _, socket) do
    live_view_action(__MODULE__, "edit_market", socket, fn ->
      market = Enum.find(socket.assigns.markets, &(&1.id == market_id))

      {:noreply,
       socket
       |> assign_data_table(:show_more, market_id)
       |> assign(%{
         edit_market: market
       })}
    end)
  end

  def handle_info(:cancel_change, socket) do
    {:noreply,
     assign(socket, %{
       show_modal: false,
       edit_market: nil
     })}
  end

  def handle_info(:markets_updated, socket) do
    live_view_action(__MODULE__, "markets_updated", socket, fn ->
      socket = update_results(socket)

      {:noreply,
       assign(socket, %{
         show_modal: false,
         edit_market: nil
       })}
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MarketsView.render("dashboard.html", assigns)
  end

  def list_records(socket, filters), do: {socket, Markets.list_markets(filters)}
end
