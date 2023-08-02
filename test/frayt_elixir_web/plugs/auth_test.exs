defmodule FraytElixirWeb.Plugs.AuthTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.AdminUser
  alias FraytElixirWeb.Plugs.Auth

  setup %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{})
    %AdminUser{user: user} = insert(:admin_user)

    {:ok,
     %{
       conn: conn,
       admin: Accounts.get_user!(user.id),
       user: insert(:user)
     }}
  end

  # describe "build_session/2" do
  #   test "adds user to session", %{conn: conn, admin: admin} do
  #     conn = Auth.build_session(conn, admin)
  #
  #     assert admin == get_session(conn, :user)
  #   end
  # end

  describe "current_user_is_admin?/1" do
    test "returns true if admin", %{conn: conn, admin: admin} do
      conn = login_user(conn, admin)
      assert Auth.current_user_is_admin?(conn)
    end

    test "returns false if NOT admin", %{conn: conn, user: user} do
      conn = login_user(conn, user)
      refute Auth.current_user_is_admin?(conn)
    end
  end

  # describe "update_user/2" do
  #   setup %{conn: conn, user: user} do
  #     conn_with_user = Plug.Test.init_test_session(conn, %{user: user})
  #     {:ok, updated_user} = Accounts.update_user(user, %{first_name: "Some Silly Name"})
  #
  #     {:ok, user_conn: conn_with_user, updated_user: updated_user}
  #   end
  #
  #   test "updates the user in the session", %{user_conn: conn, updated_user: updated_user} do
  #     assert %User{first_name: "Dude"} = Auth.current_user(conn)
  #
  #     updated_conn = Auth.update_user(conn, updated_user)
  #     assert %User{first_name: "Some Silly Name"} = Auth.current_user(updated_conn)
  #     assert %User{first_name: "Some Silly Name"} = Plug.Conn.get_session(updated_conn, "user")
  #   end
  # end
end
