defmodule FraytElixirWeb.AdminAlerts do
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  import Phoenix.LiveView.Helpers

  defmacro __using__(_opts) do
    quote do
      import Phoenix.LiveView

      def mount(params, session, %{assigns: assigns} = socket)
          when not is_map_key(assigns, :alerts) do
        socket = assign(socket, :alerts, [])
        mount(params, session, socket)
      end

      def handle_event("close_alert:" <> alert_id, _, socket) do
        live_view_action(__MODULE__, "close_alert:" <> alert_id, socket, fn ->
          {:noreply, assign(socket, :alerts, close_alerts(socket.assigns.alerts, [alert_id]))}
        end)
      end

      def handle_info({:close_alerts, ids}, socket) do
        live_view_action(__MODULE__, "close_alerts", socket, fn ->
          {:noreply, assign(socket, :alerts, close_alerts(socket.assigns.alerts, ids))}
        end)
      end

      def handle_info({:send_alert, level, message}, %{assigns: %{alerts: alerts}} = socket) do
        live_view_action(__MODULE__, "send_alert", socket, fn ->
          Process.send_after(self(), {:close_alerts, alerts |> Enum.map(& &1.id)}, 2000)

          id = get_alert_id()

          case level do
            :info -> Process.send_after(self(), {:close_alerts, [id]}, 5000)
            _ -> nil
          end

          {:noreply,
           assign(
             socket,
             :alerts,
             alerts ++ [%{id: id, visible: true, level: level, message: message}]
           )}
        end)
      end

      defp send_alert(level, message) do
        send(self(), {:send_alert, level, message})
      end

      defp get_alert_id,
        do: :crypto.strong_rand_bytes(10) |> Base.url_encode64() |> binary_part(0, 10)

      defp close_alerts(alerts, ids) do
        alerts
        |> Enum.map(fn %{id: id} = alert ->
          case Enum.member?(ids, id) do
            true -> alert |> Map.put(:visible, false)
            false -> alert
          end
        end)
      end
    end
  end

  def render(alerts) do
    assigns = %{alerts: alerts}

    ~L"""
      <div class="alert-container">
        <%= for alert <- @alerts do %>
          <div class="alert alert-<%= alert.level %> <%= if !alert.visible do "dismissed" end %>">
            <p class="alert-content"><%= alert.message %><span class="close-alert" phx-click="close_alert:<%= alert.id %>">&times;</span></p>
          </div>
        <% end %>
      </div>
    """
  end
end
