defmodule FraytElixirWeb.Admin.ReportLive do
  use FraytElixirWeb, :live_view
  alias FraytElixir.Holistics
  alias FraytElixir.Holistics.HolisticsDashboard

  def mount(params, _session, socket) do
    dashboard =
      case Map.get(params, "id") do
        "new" -> %HolisticsDashboard{}
        id when is_binary(id) -> Holistics.get_dashboard(id)
      end

    {:ok, assign(socket, dashboard: dashboard)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ReportsView.render("show.html", assigns)
  end
end
