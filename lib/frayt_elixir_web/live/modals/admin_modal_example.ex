defmodule FraytElixirWeb.AdminModalExample do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
    <form>
      <section>
        <div class="width--full">
          <p>This is a test modal to show how the reusable modals work. It has buttons other than the cancel button, so all buttons are here.</p>
        </div>
        <div class="u-pad__top u-text--center width--full">
          <a onclick="" class="button" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal">Cancel</a>
          <button class="button button--primary" phx-click="close_modal">Save</button>
        </div>
      </section>
    </form>
    """
  end
end
