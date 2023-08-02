defmodule FraytElixirWeb.OauthControllerTest do
  use FraytElixirWeb.ConnCase

  alias FraytElixir.Accounts.ApiAccount

  describe "authenticate/2" do
    test "returns a valid JWT token", %{conn: conn} do
      %ApiAccount{client_id: client_id, secret: secret, id: api_account_id} =
        insert(:api_account_with_company)

      creds = %{client_id: client_id, secret: secret}

      conn = post(conn, Routes.oauth_path(conn, :authenticate), creds)

      assert %{"token" => token} = json_response(conn, 200)["response"]

      assert {:ok, claims} = FraytElixir.Guardian.decode_and_verify(token)
      assert claims["sub"] == api_account_id
      assert claims["aud"] == "frayt_api"
    end

    test "fails with invalid code failure", %{conn: conn} do
      %ApiAccount{client_id: client_id} = insert(:api_account_with_company)
      creds = %{client_id: client_id, secret: "foobar"}

      conn = post(conn, Routes.oauth_path(conn, :authenticate), creds)

      assert %{"code" => "invalid_credentials"} = json_response(conn, 403)
    end

    test "fails with no credentials", %{conn: conn} do
      conn = post(conn, Routes.oauth_path(conn, :authenticate), %{})

      assert %{
               "errors" => [
                 %{
                   "detail" => "Missing field: client_id",
                   "source" => %{"pointer" => "/client_id"},
                   "title" => "Invalid value"
                 },
                 %{
                   "detail" => "Missing field: secret",
                   "source" => %{"pointer" => "/secret"},
                   "title" => "Invalid value"
                 }
               ]
             } = json_response(conn, 422)
    end
  end
end
