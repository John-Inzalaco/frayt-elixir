defmodule FraytElixirWeb.Hubspot.AccountControllerTest do
  use FraytElixirWeb.ConnCase

  describe "new" do
    test "creates new account", %{conn: conn} do
      conn =
        get(conn, Routes.hubspot_account_path(conn, :new), %{"code" => "super_duper_valid_code"})

      assert html_response(conn, 200) =~ "Hooray!"
    end

    test "fails with invalid code", %{conn: conn} do
      conn =
        get(conn, Routes.hubspot_account_path(conn, :new), %{"code" => "super_duper_invalid_code"})

      assert html_response(conn, 200) =~ "An Error Occurred"
    end
  end
end
