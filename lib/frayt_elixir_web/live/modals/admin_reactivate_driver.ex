defmodule FraytElixirWeb.AdminReactivateDriver do
  use Phoenix.LiveView
  alias FraytElixir.Drivers
  import FraytElixirWeb.DisplayFunctions

  def mount(_params, session, socket) do
    {:ok,
     assign(socket, %{
       driver: session["driver"],
       sent: false,
       error: nil
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("send_email", _event, socket) do
    assigns =
      case Drivers.reactivate_driver(socket.assigns.driver) do
        {:ok, driver} -> %{sent: true, error: nil, driver: driver}
        _ -> %{error: "Something went wrong"}
      end

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("update_page", _event, socket) do
    send(socket.parent_pid, {:driver_updated, socket.assigns.driver})
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
      <%= unless @sent do %>
      <section>
        <div class="width--full">
            <p>You are about to reactivate the driver <%= full_name(@driver) %>. This will send them an email notifying them that they are able to see and accept matches. Are you sure this is what you want to do?</p>
        </div>
        <%= if @error do %>
          <p class="error"><%= @error %></p>
        <% end %>
        <div class="u-pad__top u-text--center width--full">
          <button class="button button--primary" phx-click="send_email">Yes</button>
          <button class="button" phx-click="close_modal">Cancel</button>
        </div>
      </section>
      <% else %>
        <section>
          <div class="width--full">
              <p>Email sent to <%= full_name(@driver) %>.</p>
          </div>

          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary" phx-click="update_page">OK</button>
          </div>
        </section>
      <% end %>
    """
  end
end
