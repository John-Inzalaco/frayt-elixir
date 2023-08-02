defmodule FraytElixirWeb.AdminSendCustomNotification do
  use Phoenix.LiveView
  import FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Notifications

  def mount(
        _params,
        %{"driver" => driver, "current_user" => current_user},
        socket
      ) do
    {:ok,
     assign(socket, %{
       driver: driver,
       current_user: current_user,
       fields: %{
         title: "Test Frayt Notification",
         message:
           "Hello, this is the Frayt team. We're sending a test notification to verify your phone is capable of receiving them."
       },
       sent: false,
       errors: nil
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event(
        "send_notification",
        %{"send_notification" => %{"title" => title, "message" => message}},
        %{assigns: %{current_user: current_user, driver: driver}} = socket
      ) do
    case Notifications.send_notification(:push, driver, current_user.admin, %{
           title: title,
           message: message
         }) do
      {:ok, _notification_batch} ->
        {:noreply, assign(socket, :sent, true)}

      {:error, error_msg, _} ->
        {:noreply, assign(socket, :errors, error_msg)}

      {:error, _, changeset, _} ->
        errors = changeset |> humanize_errors()

        {:noreply, assign(socket, :errors, errors)}
    end
  end

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("_send_notification.html", assigns)
  end
end
