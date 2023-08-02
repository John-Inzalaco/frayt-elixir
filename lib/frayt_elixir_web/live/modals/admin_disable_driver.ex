defmodule FraytElixirWeb.AdminDisableDriver do
  use Phoenix.LiveView
  alias FraytElixir.Drivers
  import FraytElixirWeb.DisplayFunctions

  def mount(_params, session, socket) do
    {:ok,
     assign(socket, %{
       driver: session["driver"],
       sent: false,
       notes: "",
       error: nil
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("send_email", %{"notes" => note}, socket) do
    case Drivers.disable_driver_account(socket.assigns.driver, note) do
      {:ok, driver} ->
        {:noreply, assign(socket, %{sent: true, error: nil, driver: driver})}

      _ ->
        {:noreply, assign(socket, %{error: "Something went wrong", notes: note})}
    end
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
            <p>You are about to disable the driver <%= full_name(@driver) %>. They will no longer be able to see or accept matches. Are you sure this is what you want to do?</p>
        </div>
        <form phx-submit="send_email" class="width--full">
          <div>
            <label class="optional" for="notes">Add additional note for driver</label>
            <textarea id="notes" name="notes"><%= @notes %></textarea>
          </div>

          <%= if @error do %>
            <p class="error"><%= @error %></p>
          <% end %>

          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary">Yes</button>
            <a onclick="" class="button" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal">Cancel</a>
          </div>
        </form>
      </section>
      <% else %>
        <section>
          <div class="width--full">
              <p>Email sent to <%= full_name(@driver) %>.</p>
          </div>

          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary u-push__right--xxs" phx-click="update_page">OK</button>
          </div>
        </section>
      <% end %>
    """
  end
end
