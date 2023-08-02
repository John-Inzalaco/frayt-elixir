defmodule FraytElixirWeb.DriverLocationsChannelTest do
  use FraytElixirWeb.ChannelCase
  import FraytElixir.Factory
  alias FraytElixir.Drivers.{Driver, DriverLocation}

  test "joining a driver_locations channel replies with current driver location" do
    %Driver{
      id: driver_id,
      current_location: %DriverLocation{
        geo_location: geo
      }
    } = insert(:driver, current_location: build(:driver_location))

    assert {:ok, %{geo_location: ^geo}, _socket} =
             socket(FraytElixirWeb.UserSocket, "user_id", %{})
             |> subscribe_and_join(
               FraytElixirWeb.DriverLocationsChannel,
               "driver_locations:#{driver_id}"
             )
  end

  test "joining a driver_locations channel replies with nil if no driver location" do
    %Driver{
      id: driver_id
    } = insert(:driver)

    assert {:ok, %{}, _socket} =
             socket(FraytElixirWeb.UserSocket, "user_id", %{})
             |> subscribe_and_join(
               FraytElixirWeb.DriverLocationsChannel,
               "driver_locations:#{driver_id}"
             )
  end
end
