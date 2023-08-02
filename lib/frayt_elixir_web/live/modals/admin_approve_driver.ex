defmodule FraytElixirWeb.AdminApproveDriver do
  use Phoenix.LiveView
  use FraytElixirWeb.AdminAlerts
  alias FraytElixir.Drivers
  alias FraytElixirWeb.Router.Helpers, as: Routes

  def mount(_params, %{"driver" => driver}, socket) do
    {:ok, assign(socket, %{driver: driver, approved: false, error: nil})}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)

    {:noreply,
     redirect(socket,
       to:
         Routes.driver_show_path(
           FraytElixirWeb.Endpoint,
           :add,
           socket.assigns.driver.id
         )
     )}
  end

  def handle_event("approve_driver", _event, socket) do
    driver_id = socket.assigns.driver.id
    driver = Drivers.get_driver!(driver_id)

    case Drivers.update_driver_state(driver, :approved) do
      {:ok, _} -> {:noreply, assign(socket, %{approved: true})}
      _ -> {:noreply, assign(socket, %{approved: false, error: "Something went wrong"})}
    end
  end

  def render(assigns) do
    ~L"""
    <%= unless @approved do %>
      <%= unless @error do %>
        <section>
          <div class="width--full">
            <p class="info">Are you sure you want to approve this driver?</p>
          </div>
          <div class="u-pad__top u-text--center width--full">
            <button data-test-id="confirm-driver-approval-btn" class="button button--primary" phx-click="approve_driver">
              Yes, approve
            </button>
            <button class="button" phx-click="close_modal">Cancel</button>
          </div>
        </section>
      <% else %>
        <section>
          <div class="width--full">
            <p class="error"><%= @error %></p>
          </div>
        </section>
      <% end %>
    <% else %>
      <section>
        <div class="width--full">
          <p data-test-id="success-message" class="success">The driver has been approved successfully!</p>
        </div>
        <div class="u-pad__top u-text--center width--full">
          <button class="button" phx-click="close_modal">Close</button>
        </div>
      </section>
    <% end %>
    """
  end
end
