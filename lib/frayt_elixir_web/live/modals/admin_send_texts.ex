defmodule FraytElixirWeb.AdminSendTexts do
  use Phoenix.LiveView
  import FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Notifications
  alias FraytElixir.Drivers
  require Logger

  def mount(
        _params,
        %{"match" => match, "filters" => filters, "admin" => admin, "time_zone" => time_zone},
        socket
      ) do
    max_mass_texts = Notifications.get_max_daily_admin_mass_notifications()

    filters = Map.drop(filters, [:per_page, :page])

    drivers =
      case Drivers.list_capacity_drivers(filters, 50) do
        {:ok, drivers, _updated_state} -> drivers
        _ -> []
      end

    {:ok,
     assign(socket, %{
       match: match,
       drivers: drivers,
       admin: admin,
       max_mass_texts: max_mass_texts,
       used_mass_texts: Notifications.get_used_daily_admin_mass_notifications(admin, time_zone),
       fields: %{
         message:
           "Hello, this is the Frayt team. We're letting you know that Match ##{match.shortcode} is available in your area. You would be driving #{match.total_distance} miles for $#{cents_to_dollars(match.driver_total_pay)}. If this interests you, feel free to open your Driver app to accept it."
       },
       errors: []
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event(
        "send_texts",
        %{"send_texts" => %{"message" => message}},
        %{assigns: %{match: match, admin: admin, drivers: drivers}} = socket
      ) do
    {:ok, notification_batch, errors} =
      Notifications.send_notification_batch(admin, match, drivers, %{body: message})

    send(
      socket.parent_pid,
      {:sent_texts,
       %{
         attempted: Enum.count(drivers),
         succeeded: Enum.count(notification_batch.sent_notifications),
         failed_message: build_error_message(errors)
       }}
    )

    {:noreply, socket}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.CapacityView.render("_send_texts.html", assigns)
  end

  defp build_error_message(errors) when length(errors) > 0 do
    message =
      Enum.map_join(errors, ", ", fn {error, meta} ->
        "#{meta[:to].first_name} #{meta[:to].last_name} (#{meta[:phone_number]}" <>
          case error do
            %{"message" => message} -> ", reason: #{message})"
            _ -> ")"
          end
      end)

    "Failed for: #{message}"
  end

  defp build_error_message(_errors), do: ""
end
