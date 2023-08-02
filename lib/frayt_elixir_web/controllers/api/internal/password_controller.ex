defmodule FraytElixirWeb.API.Internal.PasswordController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Accounts

  action_fallback FraytElixirWeb.FallbackController

  def update(conn, password_params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, _user} <- Accounts.change_password(user, password_params) do
      send_resp(conn, :no_content, "")
    end
  end
end
