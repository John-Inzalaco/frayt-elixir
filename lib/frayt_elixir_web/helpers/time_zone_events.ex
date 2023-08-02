defmodule FraytElixirWeb.TimeZoneEvents do
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      def mount(params, session, %{assigns: assigns} = socket)
          when not is_map_key(assigns, :time_zone),
          do: mount(params, session, assign(socket, :time_zone, "UTC"))

      def handle_event("client_timezone", %{"tz" => tz}, socket) do
        live_view_action(__MODULE__, "client_timezone", socket, fn ->
          env = Application.get_env(:frayt_elixir, :environment)
          tz = if(env in [:dev, :prod], do: tz, else: "UTC")

          {:noreply, assign(socket, :time_zone, tz)}
        end)
      end
    end
  end
end
