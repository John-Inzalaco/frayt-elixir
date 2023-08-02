defmodule FraytElixirWeb.API.Internal.DriverDeviceView do
  use FraytElixirWeb, :view

  alias FraytElixirWeb.API.Internal.DriverDeviceView

  def render("show.json", %{device: device}) do
    %{response: render_one(device, DriverDeviceView, "device.json")}
  end

  def render("device.json", %{driver_device: device}) do
    %{
      id: device.id,
      device_uuid: device.device_uuid,
      device_model: device.device_model,
      player_id: device.player_id,
      os: device.os,
      os_version: device.os_version,
      is_tablet: device.is_tablet,
      is_location_enabled: device.is_location_enabled,
      driver_id: device.driver_id
    }
  end

  def render("success.json", _) do
    %{
      data: %{
        message: "Successfully sent test notification"
      }
    }
  end
end
