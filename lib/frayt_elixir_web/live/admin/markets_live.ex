defmodule FraytElixirWeb.Admin.MarketsLive do
  use FraytElixirWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MarketsView.render("index.html", assigns)
  end
end
