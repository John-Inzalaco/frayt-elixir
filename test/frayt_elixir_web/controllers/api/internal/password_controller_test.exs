defmodule FraytElixirWeb.API.Internal.PasswordControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "update" do
    setup [:login_as_shipper]

    test "update password", %{conn: conn} do
      frontend_params = %{
        "old" => "password",
        "new" => "newsupersecretpassword@1"
      }

      conn = put(conn, Routes.api_v2_password_path(conn, :update, ".1"), frontend_params)
      assert response(conn, 204)
    end

    test "update password fails if you start with the wrong password", %{conn: conn} do
      frontend_params = %{
        "old" => "wrongpassword",
        "new" => "newsupersecretpassword@1"
      }

      conn = put(conn, Routes.api_v2_password_path(conn, :update, ".1"), frontend_params)
      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end
  end
end
