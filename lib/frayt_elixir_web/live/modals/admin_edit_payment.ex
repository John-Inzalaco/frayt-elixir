defmodule FraytElixirWeb.AdminEditPaymentModal do
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
          <div class="width--two-thirds">
            <div>
              <label class="label">Payer</label>
              <input class="input" placeholder="Shipper Email"></input>
            </div>
            <div>
              <label class="label">Total</label>
              <div>
                <input class="input" placeholder="$"></input>
              </div>
            </div>
          </div>
        </div>
        <div class="width--full">
          <div class="width--two-thirds">
            <div>
              <label class="label">Payee</label>
              <input class="input" placeholder="Driver Email"></input>
            </div>
            <div>
              <label class="label">Driver's Cut</label>
              <div>
                <input class="input" placeholder="$"></input>
              </div>
            </div>
          </div>
        </div>
        <div class="u-pad__top u-text--center width--full">
          <a onclick="" class="button" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal">Cancel</a>
          <button class="button button--primary" phx-click="close_modal">Update</button>
        </div>
      </section>
    </form>
    """
  end
end
