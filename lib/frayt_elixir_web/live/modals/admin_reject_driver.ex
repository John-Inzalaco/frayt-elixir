defmodule FraytElixirWeb.AdminRejectDriver do
  use Phoenix.LiveView
  use FraytElixirWeb.AdminAlerts
  alias FraytElixir.Drivers
  alias FraytElixirWeb.Router.Helpers, as: Routes
  alias FraytElixir.Notifications.DriverNotification
  alias FraytElixir.Repo

  def mount(_params, %{"driver" => driver}, socket) do
    {:ok, assign(socket, %{driver: driver, rejected: false, error: nil})}
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

  def handle_event("reject_driver", _event, socket) do
    driver_id = socket.assigns.driver.id
    driver = Drivers.get_driver!(driver_id) |> Repo.preload(:user)

    case Drivers.update_driver_state(driver, :rejected) do
      {:ok, _} ->
        DriverNotification.send_rejection_letter_email(driver)
        {:noreply, assign(socket, %{rejected: true})}

      _ ->
        {:noreply, assign(socket, %{rejected: false, error: "Something went wrong"})}
    end
  end

  def render(assigns) do
    ~L"""
    <%= unless @rejected do %>
      <%= unless @error do %>
        <section>
          <div class="width--full">
            <p class="info">Are you sure you want to reject this driver?</p>
          </div>
          <div class="u-pad__top u-text--center width--full">
            <button class="button button--danger" phx-click="reject_driver">Yes, reject</button>
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
          <p class="success">The driver has been rejected successfully!</p>
        </div>
        <div class="u-pad__top u-text--center width--full">
          <button class="button" phx-click="close_modal">Close</button>
        </div>
      </section>
    <% end %>
    """
  end
end
