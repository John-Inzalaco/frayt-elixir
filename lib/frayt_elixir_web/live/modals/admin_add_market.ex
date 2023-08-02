defmodule FraytElixirWeb.AdminAddMarket do
  use Phoenix.LiveView
  alias FraytElixir.Markets.Market

  def mount(_params, %{"current_user" => current_user}, socket) do
    {:ok, assign(socket, current_user: current_user)}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_info(name, socket) do
    send(socket.parent_pid, name)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
      <%= live_component(FraytElixirWeb.LiveComponent.MarketFormComponent, id: :add_market, market: %Market{zip_codes: []}, current_user: @current_user) %>
    """
  end
end
