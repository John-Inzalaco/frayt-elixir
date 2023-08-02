defmodule FraytElixirWeb.ModalEvents do
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView
      import FraytElixir.AtomizeKeys

      def handle_event("show_modal", _event, socket) do
        live_view_action(__MODULE__, "show_modal", socket, fn ->
          {:noreply, open_modal(socket)}
        end)
      end

      def handle_event(
            "show_modal_named",
            %{"liveview" => live_view} = params,
            socket
          ) do
        live_view_action(__MODULE__, "show_modal_named", socket, fn ->
          {:noreply, show_modal(socket, live_view, params)}
        end)
      end

      def handle_event("close_modal", _event, socket) do
        live_view_action(__MODULE__, "close_modal", socket, fn ->
          {:noreply, close_modal(socket)}
        end)
      end

      def handle_info({:set_title, title}, socket), do: {:noreply, assign(socket, :title, title)}

      def handle_info(:close_modal, socket) do
        live_view_action(__MODULE__, "close_modal", socket, fn ->
          {:noreply, close_modal(socket)}
        end)
      end

      def open_modal(socket) do
        assign(socket, :show_modal, true)
      end

      defp close_modal(socket) do
        assign(socket, :show_modal, false)
      end

      defp show_modal(socket, live_view, assigns) when is_binary(live_view) do
        module = String.to_atom("Elixir.FraytElixirWeb.#{live_view}")

        show_modal(socket, module, assigns)
      end

      defp show_modal(socket, module, assigns) do
        assigns =
          assigns
          |> atomize_keys()
          |> Map.delete(:liveview)
          |> Map.put(:live_view, module)

        socket
        |> assign(assigns)
        |> open_modal()
      end
    end
  end
end
