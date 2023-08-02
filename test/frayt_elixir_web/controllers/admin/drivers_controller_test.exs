defmodule FraytElixirWeb.Admin.DriversControllerTest do
  use FraytElixirWeb.ConnCase
  use Wallaby.DSL
  import FraytElixirWeb.Admin.DriversController
  import FraytElixirWeb.Test.LoginHelper
  alias FraytElixirWeb.Test.FileHelper
  alias FraytElixir.DriverDocuments

  setup [:login_as_admin]

  test "driver_photos with no existing license", %{conn: conn} do
    %{id: driver_id} = insert(:driver, images: [])

    conn =
      driver_photos(conn, %{
        "id" => driver_id,
        "driver_photos" => %{
          "license" => %{
            "document" => %Plug.Upload{path: FileHelper.image_path()},
            "expires_at" => "2024-01-01"
          }
        }
      })

    assert redirected_to(conn) == "/admin/drivers/#{driver_id}"

    %{document: license_photo, expires_at: expires_at} =
      DriverDocuments.get_latest_driver_document(driver_id, "license")

    assert license_photo.file_name =~ "license-"
    assert expires_at == ~D[2024-01-01]
  end

  test "driver_photos with existing license", %{conn: conn} do
    %{id: driver_id} =
      insert(:driver, images: [build(:driver_document, type: "license", expires_at: "2022-01-01")])

    %{document: license_photo} = DriverDocuments.get_latest_driver_document(driver_id, "license")

    # insert is going too fast.
    :timer.sleep(1000)

    conn =
      driver_photos(conn, %{
        "id" => driver_id,
        "driver_photos" => %{
          "license" => %{
            "document" => %Plug.Upload{path: FileHelper.image_path()},
            "expires_at" => "2024-01-01"
          }
        }
      })

    assert redirected_to(conn) == "/admin/drivers/#{driver_id}"

    %{document: updated_license_photo, expires_at: expires_at} =
      DriverDocuments.get_latest_driver_document(driver_id, "license")

    refute license_photo == updated_license_photo
    refute license_photo.file_name == updated_license_photo.file_name
    assert updated_license_photo.file_name =~ "license-"
    assert expires_at == ~D[2024-01-01]
  end
end
