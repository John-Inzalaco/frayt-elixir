defmodule FraytElixirWeb.Plugs.CheckAdmin do
  import Plug.Conn
  import Phoenix.Controller
  alias FraytElixirWeb.Router.Helpers, as: Routes

  def init(default), do: default

  def call(conn, _) do
    if FraytElixirWeb.Plugs.Auth.current_user_is_admin?(conn) do
      conn
    else
      conn
      |> put_flash(:warning, "Page not found.")
      |> redirect(to: Routes.session_path(conn, :logged_out, redirect_url: conn.request_path))
      |> halt()
    end
  end
end
