defmodule FraytElixirWeb.Plugs.Auth do
  use FraytElixirWeb, :controller
  import Plug.Conn
  alias FraytElixir.Guardian
  alias FraytElixir.Accounts.{AdminUser, User}

  def build_session(conn, user) do
    Guardian.Plug.sign_in(conn, user)
    # |> put_session(:user, user)
  end

  def current_user(conn) do
    Guardian.Plug.current_resource(conn)
    # case get_session(conn, "user") do
    #   nil -> Guardian.Plug.current_resource(conn)
    #   user -> user
    # end
  end

  def current_user_is_admin?(conn) do
    case current_user(conn) do
      %User{admin: %AdminUser{}} -> true
      _ -> false
    end
  end

  def browser_sign_out(conn) do
    conn
    |> Guardian.Plug.sign_out()
    |> configure_session(drop: true)
  end

  # def update_user(conn, %User{} = user) do
  #   case Guardian.Plug.current_claims(conn) do
  #     nil ->
  #       put_session(conn, :user, user)
  #
  #     claims ->
  #       Guardian.build_claims(claims, Guardian.resource_from_claims(claims), user: user)
  #       put_session(conn, :user, user)
  #   end
  # end
end
