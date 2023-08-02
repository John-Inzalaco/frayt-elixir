defmodule FraytElixirWeb.AdminAssignMatch do
  use Phoenix.LiveView

  def mount(_params, %{"match" => match}, socket), do: {:ok, assign(socket, %{match: match})}

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("assign_match", %{"assign_match" => %{"assignment" => admin_id}}, socket) do
    send(socket.parent_pid, {:assign_admin_to_match, socket.assigns.match, admin_id})
    send(socket.parent_pid, :close_modal)

    {:noreply, socket}
  end

  def render(assigns), do: FraytElixirWeb.Admin.MatchesView.render("assign_match.html", assigns)
end
