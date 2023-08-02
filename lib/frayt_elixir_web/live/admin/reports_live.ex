defmodule FraytElixirWeb.Admin.ReportsLive do
  use FraytElixirWeb, :live_view
  alias FraytElixir.Holistics

  def mount(_params, _session, socket) do
    dashboards = Holistics.list_dashboards()
    {:ok, assign(socket, dashboards: dashboards)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ReportsView.render("index.html", assigns)
  end
end
