defmodule FraytElixir.DevicesTest do
  use FraytElixir.DataCase

  import FraytElixir.Factory

  alias FraytElixir.Devices
  alias FraytElixir.Devices.DriverDevice
  alias FraytElixir.Drivers.Driver

  describe "get_device!/1" do
    test "returns device" do
      %{id: device_id} = insert(:device, driver: insert(:driver))

      assert %DriverDevice{id: ^device_id} = Devices.get_device!(device_id)
    end

    test "returns nil for nil id" do
      refute Devices.get_device!(nil)
    end
  end

  describe "upsert_driver_device/2" do
    @attrs %{
      device_uuid: "device_uuid",
      device_model: "device_model",
      player_id: "onesignal",
      os: "os",
      os_version: "os_version",
      is_tablet: false,
      is_location_enabled: true,
      app_version: "1.0.0",
      app_revision: "52",
      app_build_number: 80
    }

    test "creates a device" do
      driver = insert(:driver)

      assert {:ok,
              %Driver{
                default_device: %DriverDevice{
                  device_uuid: "device_uuid",
                  device_model: "device_model",
                  player_id: "onesignal",
                  os: "os",
                  os_version: "os_version",
                  is_tablet: false,
                  is_location_enabled: true,
                  app_version: "1.0.0",
                  app_revision: "52",
                  app_build_number: 80
                }
              }} = Devices.upsert_driver_device(driver, @attrs)
    end

    test "creates a device if its doesn't already exists" do
      driver = insert(:driver)
      device = insert(:device, driver: driver, device_uuid: "old")
      driver = set_driver_default_device(driver, device)

      assert {:ok, %Driver{default_device: %DriverDevice{id: updated_device_id}}} =
               Devices.upsert_driver_device(driver, @attrs)

      refute updated_device_id == device.id
    end

    test "updates existing device" do
      driver = insert(:driver)

      %{id: device_id} =
        insert(:device, driver: driver, device_uuid: @attrs[:device_uuid], player_id: "old")

      assert {:ok, %Driver{default_device: %DriverDevice{id: ^device_id, player_id: "onesignal"}}} =
               Devices.upsert_driver_device(driver, @attrs)
    end

    test "keeps original default device when identical" do
      driver = insert(:driver)

      %{id: device_id} =
        device = insert(:device, driver: driver, device_uuid: @attrs[:device_uuid])

      set_driver_default_device(driver, device)

      assert {:ok, %Driver{default_device: %DriverDevice{id: ^device_id}}} =
               Devices.upsert_driver_device(%{driver | default_device_id: device_id}, @attrs)
    end
  end
end
