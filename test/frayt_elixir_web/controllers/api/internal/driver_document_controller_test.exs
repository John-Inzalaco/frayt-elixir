defmodule FraytElixirWeb.API.Internal.DriverDocumentontrollerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixirWeb.Test.FileHelper

  describe "get profile_photo" do
    setup [:login_as_driver, :create_driver]

    test "redirects to file", %{conn: conn, profiled_driver: driver} do
      conn =
        get(
          conn,
          Routes.api_v2_driver_driver_document_path(conn, :profile_photo, ".1", driver.id)
        )

      assert redirected_to(conn, 302)
    end

    test "with no profile image returns 404", %{conn: conn} do
      driver = insert(:driver, images: [])
      {:ok, conn: conn, driver: _driver} = login_as_driver(conn, driver)

      conn =
        get(
          conn,
          Routes.api_v2_driver_driver_document_path(conn, :profile_photo, ".1", driver.id)
        )

      assert response(conn, 404)
    end
  end

  describe "update_photo" do
    setup [:login_as_driver]

    test "upload license photo", %{conn: conn, driver: driver} do
      conn = add_token_for_driver(conn, driver)

      conn =
        put(
          conn,
          Routes.api_v2_driver_driver_document_path(conn, :update_photo, ".1", driver),
          %{
            "photo" => %{
              document: FileHelper.base64_image(),
              type: "license",
              expiration_date: ~D[2030-01-01]
            }
          }
        )

      assert %{
               "type" => "license",
               "expires_at" => "2030-01-01"
             } = json_response(conn, 201)
    end

    test "upload vehicle photo", %{conn: conn, driver: driver} do
      conn = add_token_for_driver(conn, driver)

      conn =
        put(
          conn,
          Routes.api_v2_driver_driver_document_path(conn, :update_photo, ".1", driver),
          %{
            "photo" => %{
              document: FileHelper.base64_image(),
              type: "registration",
              expiration_date: ~D[2030-01-01]
            }
          }
        )

      assert %{
               "type" => "registration",
               "expires_at" => "2030-01-01"
             } = json_response(conn, 201)
    end

    test "invalid document_type is not allowed", %{conn: conn, driver: driver} do
      conn = add_token_for_driver(conn, driver)

      conn =
        put(
          conn,
          Routes.api_v2_driver_driver_document_path(conn, :update_photo, ".1", driver),
          %{
            "photo" => %{
              document: FileHelper.base64_image(),
              type: "random",
              expiration_date: ~D[2030-01-01]
            }
          }
        )

      assert %{
               "code" => "invalid_attributes",
               "message" => "Type is invalid"
             } = json_response(conn, 422)
    end
  end

  defp create_driver(_) do
    driver = insert(:profiled_driver)

    {:ok, profiled_driver: driver}
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end
end
