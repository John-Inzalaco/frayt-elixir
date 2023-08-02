defmodule FraytElixirWeb.DataTable.Root do
  defmacro __using__(_) do
    quote do
      import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]

      def handle_params(_params, _session, socket) do
        live_view_action(__MODULE__, "handle_params", socket, fn ->
          {:noreply, socket}
        end)
      end

      def handle_info({:data_table, :push_patch, opts}, socket) do
        {:noreply, Phoenix.LiveView.push_patch(socket, opts)}
      end

      defoverridable handle_params: 3
    end
  end
end
