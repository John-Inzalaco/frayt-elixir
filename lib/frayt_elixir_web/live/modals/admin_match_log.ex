defmodule FraytElixirWeb.AdminMatchLog do
  use Phoenix.LiveView
  alias FraytElixir.MatchLog

  def mount(_params, session, socket) do
    {:ok,
     assign(socket, %{
       actions: MatchLog.get_match_log(session["match"]),
       time_zone: session["time_zone"],
       match: session["match"]
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("match_log.html", assigns)
  end
end
