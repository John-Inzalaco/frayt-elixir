defmodule FraytElixirWeb.AdminEditDriver do
  use Phoenix.LiveView
  alias FraytElixir.Drivers
  alias FraytElixir.Repo

  def mount(_params, session, socket) do
    driver = session["driver"]

    {:ok, assign(socket, changeset: Drivers.change_driver(driver), driver: driver)}
  end

  def handle_event("toggle_edit", _event, socket) do
    send(socket.parent_pid, :close_edit)
    {:noreply, socket}
  end

  def handle_event("change_driver", %{"driver" => attrs}, socket) do
    changeset = Drivers.change_driver(socket.assigns.driver, attrs)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("update_driver", %{"driver" => attrs}, socket) do
    assigns =
      case Drivers.update_driver(socket.assigns.driver, attrs) do
        {:ok, driver} ->
          driver = Repo.preload(driver, :market, force: true)
          send(socket.parent_pid, {:driver_updated, driver})

          %{changeset: nil, driver: driver}

        {:error, changeset} ->
          %{changeset: changeset}
      end

    {:noreply, assign(socket, assigns)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("edit_driver.html", assigns)
  end
end
