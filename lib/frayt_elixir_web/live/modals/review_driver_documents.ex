defmodule FraytElixirWeb.ReviewDriverDocuments do
  use Phoenix.LiveView

  alias FraytElixir.DriverDocuments

  def mount(_params, %{"driver" => driver, "title" => title}, socket) do
    changeset = DriverDocuments.change_driver_documents(driver)

    {:ok,
     assign(socket,
       title: title,
       changeset: changeset,
       driver: driver
     )}
  end

  def handle_event("change_documents", %{"driver" => attrs}, socket) do
    changeset =
      DriverDocuments.change_driver_documents(socket.assigns.driver, attrs)
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("update_documents", %{"driver" => attrs}, socket) do
    case DriverDocuments.review_driver_documents(socket.assigns.driver, attrs) do
      {:ok, driver} ->
        send(socket.parent_pid, {:driver_updated, driver})
        send(socket.parent_pid, :close_modal)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("_review_driver_documents.html", assigns)
  end
end
