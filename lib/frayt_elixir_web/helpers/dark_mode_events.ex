defmodule FraytElixirWeb.DarkModeEvents do
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  alias FraytElixir.Accounts

  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      def handle_event("toggle_dark_mode", _event, %{assigns: %{current_user: user}} = socket) do
        live_view_action(__MODULE__, "toggle_dark_mode", socket, fn ->
          user =
            case Accounts.toggle_admin_theme(user.admin) do
              {:ok, admin} -> %Accounts.User{user | admin: admin}
              _ -> user
            end

          {:noreply, assign(socket, :current_user, user)}
        end)
      end
    end
  end
end
