defmodule FraytElixirWeb.AssignCurrentUser do
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      def mount(params, %{"current_user" => current_user} = session, %{assigns: assigns} = socket)
          when not is_map_key(assigns, :current_user) do
        socket = assign(socket, :current_user, current_user)

        ExAudit.track(user_id: current_user.id)

        mount(params, session, socket)
      end
    end
  end
end
