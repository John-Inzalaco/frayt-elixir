defmodule FraytElixirWeb.API.Internal.DriverViewTest do
  use FraytElixirWeb.ConnCase, async: true

  alias FraytElixirWeb.API.Internal.DriverView

  describe "driver.json" do
    test "driver's last name is not truncated" do
      driver = insert(:driver, first_name: "John", last_name: "Doe")
      rendered_driver = DriverView.render("driver.json", %{driver: driver})

      assert %{
               first_name: "John",
               last_name: "Doe"
             } = rendered_driver
    end
  end
end
