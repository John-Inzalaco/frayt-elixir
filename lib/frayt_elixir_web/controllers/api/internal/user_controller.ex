defmodule FraytElixirWeb.API.Internal.UserController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.User

  import FraytElixirWeb.UrlHelper

  action_fallback FraytElixirWeb.FallbackController

  def index(conn, _params) do
    users = Accounts.list_users()
    render(conn, "index.json", users: users)
  end

  def create(%{assigns: %{version: version}} = conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", get_api_user_url(version, user))
      |> render("show.json", user: user)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, "show.json", user: user)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Accounts.get_user!(id)

    with {:ok, %User{} = user} <- Accounts.update_user(user, user_params) do
      render(conn, "show.json", user: user)
    end
  end

  def forgot_password(conn, %{"email" => email}) do
    Accounts.forgot_password(email)
    send_resp(conn, 200, "")
  end

  def reset_password(conn, %{
        "password_reset_code" => code,
        "password" => password,
        "password_confirmation" => confirmation
      }) do
    %User{email: email} = Guardian.Plug.current_resource(conn)

    with {:ok, %User{} = _user} <- Accounts.reset_password(email, code, password, confirmation) do
      send_resp(conn, 200, "")
    end
  end
end
