defmodule FraytElixirWeb.AdminUpdateShipperState do
  use Phoenix.LiveView
  alias FraytElixir.Accounts
  import FraytElixirWeb.DisplayFunctions

  def mount(_params, session, socket) do
    {:ok,
     assign(socket, %{
       shipper: Accounts.get_shipper!(session["shipper_id"]),
       shipper_state: session["shipper_state"]
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("update_page", _event, socket) do
    {:ok, _shipper} =
      Accounts.update_shipper(socket.assigns.shipper, %{state: socket.assigns.shipper_state})

    send(socket.parent_pid, :shippers_updated)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
      <section>
        <div class="width--full">
          <%= cond do %>
            <% @shipper_state == "approved" and @shipper.state == "pending_approval" -> %>
              <p>Are you sure you want to approve <%= full_name(@shipper) %>. They will be able to sign in to their account. Are you sure this is what you want to do?</p>

            <% @shipper_state == "approved" -> %>
              <p>You are about to reactivate the shipper <%= full_name(@shipper) %>. They will be able to sign in to their account. Are you sure this is what you want to do?</p>

            <% true -> %>
              <p>You are about to disable the shipper <%= full_name(@shipper) %>. They will no longer be able to sign in to their account. Are you sure this is what you want to do?</p>
          <% end %>
        </div>

        <div class="u-pad__top u-text--center width--full">
          <button class="button button--primary" phx-click="update_page">Yes</button>
          <a class="button" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal">Cancel</a>
        </div>
      </section>
    """
  end
end
