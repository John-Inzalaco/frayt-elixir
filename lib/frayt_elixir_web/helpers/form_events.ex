defmodule FraytElixirWeb.FormEvents do
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      # Ignore record search events
      def handle_event(_action, %{"_target" => ["record_search_" <> _]} = event, socket) do
        {:noreply, socket}
      end
    end
  end
end
