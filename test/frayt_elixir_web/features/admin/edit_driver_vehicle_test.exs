defmodule FraytElixirWeb.Admin.EditDriverVehicleTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  alias FraytElixirWeb.Test.EditDriverVehiclePage

  setup [:create_and_login_admin]

  feature "can edit driver vehicle", %{session: session} do
    %{id: driver_id} = insert(:driver)

    session
    |> Admin.visit_page("drivers/#{driver_id}")
    |> click(button("Edit Vehicle"))
    |> EditDriverVehiclePage.fill_fields(
      %{
        make: "Some make",
        model: "Some model",
        year: "2017",
        vin: "ASD123KL9456",
        license_plate: "KFD1234",
        cargo_area_width: "12",
        cargo_area_length: "43",
        cargo_area_height: "23",
        wheel_well_width: "5",
        max_cargo_weight: "10",
        door_width: "14",
        door_height: "23"
      },
      "input"
    )
    |> EditDriverVehiclePage.fill_fields(%{vehicle_class: "3"}, "select")
    |> click(button("Update Vehicle"))
    |> EditDriverVehiclePage.assert_vehicle(%{
      make: "Some make",
      model: "Some model",
      year: "2017",
      vin: "ASD123KL9456",
      vehicle_type: "Cargo Van",
      license_plate: "KFD1234",
      cargo_area_width: "12",
      cargo_area_length: "43",
      cargo_area_height: "23",
      wheel_well_width: "5",
      max_cargo_weight: "10",
      door_width: "14",
      door_height: "23"
    })
  end
end
