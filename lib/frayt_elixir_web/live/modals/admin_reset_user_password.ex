defmodule FraytElixirWeb.AdminResetUserPassword do
  use Phoenix.LiveView
  alias FraytElixir.Accounts
  alias FraytElixir.Drivers

  def mount(_params, session, socket) do
    entity =
      case session do
        %{"shipper_id" => shipper_id} -> Accounts.get_shipper!(shipper_id)
        %{"driver" => driver} -> Drivers.get_driver!(driver.id)
      end

    {:ok,
     assign(socket, %{
       email: entity.user.email,
       sent: false
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("send_email", _event, socket) do
    Accounts.forgot_password(socket.assigns.email)
    {:noreply, assign(socket, %{sent: true})}
  end

  def render(assigns) do
    ~L"""
      <%= unless @sent do %>
      <section>
        <div class="width--full">
            <p>Starting the reset password process will send a 'Forgot Password' email to <code><%= @email %></code> to reset their password. Are you sure this is what you want to do?</p>
        </div>

        <div class="u-pad__top u-text--center width--full">
          <button class="button button--primary" phx-click="send_email">Yes, send</button>
          <button class="button" phx-click="close_modal">Cancel</button>
        </div>
      </section>
      <% else %>
        <section>
          <div class="width--full">
              <p>Email sent to <code><%= @email %></code>.</p>
          </div>

          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary" phx-click="close_modal">OK</button>
          </div>
        </section>
      <% end %>
    """
  end
end
