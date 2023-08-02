defmodule FraytElixirWeb.AdminRenewMatch do
  use Phoenix.LiveView
  alias FraytElixir.Shipment.MatchWorkflow
  import FraytElixirWeb.DisplayFunctions, only: [humanize_update_errors: 2]

  def mount(_params, session, socket) do
    {:ok, assign(socket, %{match: session["match"]})}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("renew_match", _event, socket) do
    case MatchWorkflow.admin_renew_match(socket.assigns.match) do
      {:ok, match} ->
        send(socket.parent_pid, {:match_renewed, match})

      error ->
        send(
          socket.parent_pid,
          {:send_alert, :danger, humanize_update_errors(error, "Match")}
        )
    end

    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
      <section>
        <div class="width--full">
            <p>Are you sure you want to renew this match?</p>
            <p>This will revert it back to the last state it was in. If a driver was already assigned to this match before it was canceled, they will be re-assigned to it. Please remember to remove them from the match if they're no longer able to take it.</p>
            <p>If a match was canceled after completion, it will revert to all stops delivered without being completed.</p>
        </div>
        <form phx-submit="renew_match" class="width--full">
          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary">Renew Match</button>
            <a class="button" onclick="" phx-keyup="close_modal" phx-key="Enter" tabindex=0 phx-click="close_modal">Cancel</a>
          </div>
        </form>
      </section>
    """
  end
end
