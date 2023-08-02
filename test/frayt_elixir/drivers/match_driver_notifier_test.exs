defmodule FraytElixir.Drivers.MatchDriverNotifierTest do
  use FraytElixir.DataCase

  import FraytElixir.Factory

  import Ecto.Query

  alias FraytElixir.Repo

  alias FraytElixir.Drivers.MatchDriverNotifier
  alias FraytElixir.Drivers
  alias FraytElixir.Notifications.SentNotification

  describe "start_notifications" do
    test "search radius is immediately increased when no drivers are found" do
      %{driver: driver} =
        driver_location = insert(:driver_location, geo_location: findlay_market_point())

      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, findlay_market_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      MatchDriverNotifier.new(%{
        match: match,
        interval: 500,
        distance_increment: 5,
        final_distance_increment: 10
      })

      :timer.sleep(100)

      query = from sent in SentNotification, where: sent.driver_id == ^driver_location.driver_id
      sent_notifications = Repo.all(query)

      assert Enum.count(sent_notifications) == 1
    end

    test "search radius increases by increments each specified interval" do
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      %{driver: close_driver} =
        driver_location_within_30_miles =
        insert(:driver_location, geo_location: findlay_market_point())

      close_driver = set_driver_default_device(close_driver)

      Drivers.update_current_location(close_driver, findlay_market_point())

      %{driver: farther_driver} =
        driver_location_within_max_radius =
        insert(:driver_location, geo_location: wilmington_point())

      farther_driver = set_driver_default_device(farther_driver)

      Drivers.update_current_location(farther_driver, wilmington_point())

      MatchDriverNotifier.new(%{
        match: match,
        interval: 90,
        distance_increment: 5,
        final_distance_increment: 10
      })

      query =
        from sent in SentNotification,
          where:
            sent.driver_id in [
              ^driver_location_within_30_miles.driver_id,
              ^driver_location_within_max_radius.driver_id
            ]

      :timer.sleep(100)
      sent_notifications = Repo.all(query)
      assert Enum.count(sent_notifications) == 1
      :timer.sleep(300)
      sent_notifications = Repo.all(query)
      assert Enum.count(sent_notifications) == 2
      :timer.sleep(500)
      sent_notifications = Repo.all(query)
      assert Enum.count(sent_notifications) == 2
    end

    test "sends notification to preferred driver for deliver pro match" do
      %{id: preferred_driver_id} = driver = insert(:driver)
      set_driver_default_device(driver)

      %{driver: decoy_driver} =
        _driver_location_within_30_miles =
        insert(:driver_location, geo_location: findlay_market_point())

      set_driver_default_device(decoy_driver)

      Drivers.update_current_location(decoy_driver, findlay_market_point())

      gaslight_address = build(:address, geo_location: gaslight_point())

      match =
        insert(:match,
          preferred_driver_id: preferred_driver_id,
          platform: :deliver_pro,
          origin_address: gaslight_address
        )

      MatchDriverNotifier.new(%{
        match: match,
        interval: 90,
        distance_increment: 5,
        final_distance_increment: 10
      })

      :timer.sleep(500)
      query = from sent in SentNotification, where: sent.match_id == ^match.id
      assert [%{driver_id: ^preferred_driver_id}] = Repo.all(query)
    end

    test "sends no notification for deliver pro match without a preferred driver set" do
      match =
        insert(:match,
          preferred_driver_id: nil,
          platform: :deliver_pro
        )

      MatchDriverNotifier.new(%{
        match: match,
        interval: 90,
        distance_increment: 5,
        final_distance_increment: 10
      })

      :timer.sleep(500)
      query = from sent in SentNotification, where: sent.match_id == ^match.id
      assert [] = Repo.all(query)
    end
  end
end
