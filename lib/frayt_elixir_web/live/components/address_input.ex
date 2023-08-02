defmodule FraytElixirWeb.LiveComponent.AddressInput do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, :specify_details?, false)}
  end

  def handle_event("toggle_specify_details", _, socket) do
    {:noreply, assign(socket, :specify_details?, !socket.assigns.specify_details?)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.AddressesView.render("_address_input.html", assigns)
  end
end
