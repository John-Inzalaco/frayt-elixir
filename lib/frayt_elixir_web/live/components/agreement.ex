defmodule FraytElixirWeb.LiveComponent.Agreement do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(FraytElixirWeb.Admin.SettingsView, "_agreement.html", assigns)
  end
end
