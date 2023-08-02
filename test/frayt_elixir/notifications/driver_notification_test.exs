defmodule FraytElixir.Notifications.DriverNotificationTest do
  use FraytElixir.DataCase

  import FraytElixir.Factory

  import Ecto.Query

  alias FraytElixir.Repo

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.DeliveryBatch

  alias FraytElixir.Drivers.{DriverLocation, Driver, HiddenCustomer}
  alias FraytElixir.Notifications.{SentNotification, DriverNotification}
  alias FraytElixir.Drivers

  describe "send_available_match_notification/1" do
    test "sends notification to preferred driver for match" do
      %{id: preferred_driver_id} = driver = insert(:driver)
      set_driver_default_device(driver)

      %{id: match_id} =
        match = insert(:match, platform: :deliver_pro, preferred_driver_id: preferred_driver_id)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_available_match_notification(match)

      assert %{
               driver_id: ^preferred_driver_id,
               match_id: ^match_id
             } = Repo.get(SentNotification, sent_notification_id)
    end

    test "does not send repeat notifications" do
      %{id: preferred_driver_id} = driver = insert(:driver)
      set_driver_default_device(driver)

      %{id: match_id} =
        match = insert(:match, platform: :deliver_pro, preferred_driver_id: preferred_driver_id)

      for _ <- 1..2 do
        assert {:ok, _sent} = DriverNotification.send_available_match_notification(match)
      end

      assert from(sn in SentNotification, where: sn.match_id == ^match_id)
             |> Repo.all()
             |> length() == 1
    end
  end

  describe "send_available_match_notifications" do
    test "drivers within radius that haven't been notified should be notified" do
      %{driver: driver} =
        driver_location = insert(:driver_location, geo_location: chris_house_point())

      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, chris_house_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_available_match_notifications(match, 30)

      %SentNotification{
        driver: %{id: driver_id},
        match: %{id: match_id},
        external_id: external_id
      } = Repo.get!(SentNotification, sent_notification_id) |> Repo.preload([:driver, :match])

      assert driver_location.driver.id == driver_id
      assert match.id == match_id
      assert String.length(external_id) > 0
    end

    test "drivers within radius that are not active are not notified" do
      driver = insert(:driver, state: :pending_approval)

      insert(:driver_location, geo_location: chris_house_point(), driver: driver)

      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, chris_house_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      {:ok, []} = DriverNotification.send_available_match_notifications(match, 30)
    end

    test "drivers without needed vehicle are not notified" do
      car_driver = insert(:driver, vehicles: [build(:car)])
      car_driver = set_driver_default_device(car_driver)

      midsize_driver = insert(:driver, vehicles: [build(:midsize)])
      midsize_driver = set_driver_default_device(midsize_driver)

      cargo_van_driver = insert(:driver, vehicles: [build(:cargo_van)])
      %Driver{id: cargo_van_driver_id} = set_driver_default_device(cargo_van_driver)

      box_truck_driver = insert(:driver, vehicles: [build(:box_truck)])
      %Driver{id: box_truck_driver_id} = set_driver_default_device(box_truck_driver)

      Drivers.update_current_location(car_driver, gaslight_point())
      insert(:driver_location, geo_location: gaslight_point(), driver: car_driver)
      Drivers.update_current_location(midsize_driver, gaslight_point())
      insert(:driver_location, geo_location: gaslight_point(), driver: midsize_driver)
      Drivers.update_current_location(cargo_van_driver, gaslight_point())
      insert(:driver_location, geo_location: gaslight_point(), driver: cargo_van_driver)
      Drivers.update_current_location(box_truck_driver, gaslight_point())
      insert(:driver_location, geo_location: gaslight_point(), driver: box_truck_driver)

      findlay_market_address = insert(:address, geo_location: findlay_market_point())

      car_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:car),
          origin_address: findlay_market_address
        )

      midsize_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:midsize),
          origin_address: findlay_market_address
        )

      cargo_van_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:cargo_van),
          origin_address: findlay_market_address
        )

      box_truck_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:box_truck),
          origin_address: findlay_market_address
        )

      assert {:ok, [%SentNotification{driver_id: ^cargo_van_driver_id}]} =
               DriverNotification.send_available_match_notifications(cargo_van_match, 30)

      assert {:ok, [%SentNotification{driver_id: ^box_truck_driver_id}]} =
               DriverNotification.send_available_match_notifications(box_truck_match, 30)

      assert {:ok, car_notifications} =
               DriverNotification.send_available_match_notifications(car_match, 30)

      assert Enum.count(car_notifications) == 3

      assert {:ok, midsize_notifications} =
               DriverNotification.send_available_match_notifications(midsize_match, 30)

      assert Enum.count(midsize_notifications) == 2

      assert midsize_driver.id in (midsize_notifications |> Enum.map(& &1.driver_id))
      assert cargo_van_driver_id in (midsize_notifications |> Enum.map(& &1.driver_id))
    end

    test "drivers outside of radius should not be notified" do
      %{driver: driver} = insert(:driver_location, geo_location: chicago_point())
      Drivers.update_current_location(driver, chicago_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      assert {:ok, []} = DriverNotification.send_available_match_notifications(match, 30)
    end

    test "only drivers inside of radius should be notified" do
      %{driver: %{id: driver_in_range_id} = driver} =
        insert(:driver_location, geo_location: findlay_market_point())

      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, findlay_market_point())
      %{driver: driver_out_of_range} = insert(:driver_location, geo_location: chris_house_point())
      Drivers.update_current_location(driver_out_of_range, chris_house_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      assert {:ok, [sent_notification]} =
               DriverNotification.send_available_match_notifications(match, 5)

      assert sent_notification.driver_id == driver_in_range_id
    end

    test "drivers with old location inside radius but current location outside radius should not get notified" do
      driver = insert(:driver)

      chris_house_location =
        insert(:driver_location, geo_location: chris_house_point(), driver: driver)

      Drivers.update_current_location(driver, chris_house_point())

      # travel back in time and have inserted this yesterday
      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600)
      update_query = from(dl in DriverLocation, where: dl.id == ^chris_house_location.id)
      Repo.update_all(update_query, set: [inserted_at: yesterday])

      insert(:driver_location, geo_location: chicago_point(), driver: driver)
      Drivers.update_current_location(driver, chicago_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      assert {:ok, []} = DriverNotification.send_available_match_notifications(match, 30)
    end

    test "multiple drivers in range are found" do
      [%{driver: driver}, %{driver: driver2}] =
        insert_list(2, :driver_location, geo_location: chris_house_point())

      driver = set_driver_default_device(driver)
      driver2 = set_driver_default_device(driver2)

      Drivers.update_current_location(driver, chris_house_point())
      Drivers.update_current_location(driver2, chris_house_point())
      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)
      {:ok, sent_notifications} = DriverNotification.send_available_match_notifications(match, 30)
      assert Enum.count(sent_notifications) == 2
    end

    test "Does not send to blocked drivers by company in range" do
      %{driver: driver} = insert(:driver_location, geo_location: chris_house_point())
      driver = set_driver_default_device(driver)

      %{driver: %{id: hidden_driver_by_company_id} = hidden_driver_by_company} =
        insert(:driver_location, geo_location: chris_house_point())

      hidden_driver_by_company = set_driver_default_device(hidden_driver_by_company)

      %{id: company_id} = company = insert(:company)
      shipper = insert(:shipper, location: build(:location, company: company))

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^hidden_driver_by_company_id,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "Consistently late"
              }} =
               Drivers.hide_customer_matches(
                 hidden_driver_by_company,
                 company,
                 "Consistently late"
               )

      Drivers.update_current_location(driver, chris_house_point())
      Drivers.update_current_location(hidden_driver_by_company, chris_house_point())

      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address, shipper: shipper)
      {:ok, sent_notifications} = DriverNotification.send_available_match_notifications(match, 30)

      assert Enum.count(sent_notifications) == 1
    end

    test "Does not send to blocked drivers by shipper in range" do
      %{driver: driver} = insert(:driver_location, geo_location: chris_house_point())
      driver = set_driver_default_device(driver)

      %{driver: %{id: hidden_driver_by_shipper_id} = hidden_driver_by_shipper} =
        insert(:driver_location, geo_location: chris_house_point())

      hidden_driver_by_shipper = set_driver_default_device(hidden_driver_by_shipper)

      company = insert(:company)
      %{id: shipper_id} = shipper = insert(:shipper, location: build(:location, company: company))

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^hidden_driver_by_shipper_id,
                company_id: nil,
                shipper_id: ^shipper_id,
                reason: "Consistently late"
              }} =
               Drivers.hide_customer_matches(
                 hidden_driver_by_shipper,
                 shipper,
                 "Consistently late"
               )

      Drivers.update_current_location(driver, chris_house_point())
      Drivers.update_current_location(hidden_driver_by_shipper, chris_house_point())
    end

    test "Does not send to Drivers blocked by either company or shipper in range" do
      [%{driver: driver}, %{driver: driver2}] =
        insert_list(2, :driver_location, geo_location: chris_house_point())

      driver = set_driver_default_device(driver)
      driver2 = set_driver_default_device(driver2)

      %{driver: %{id: hidden_driver_by_company_id} = hidden_driver_by_company} =
        insert(:driver_location, geo_location: chris_house_point())

      %{driver: %{id: hidden_driver_by_shipper_id} = hidden_driver_by_shipper} =
        insert(:driver_location, geo_location: chris_house_point())

      hidden_driver_by_company = set_driver_default_device(hidden_driver_by_company)
      hidden_driver_by_shipper = set_driver_default_device(hidden_driver_by_shipper)

      %{id: company_id} = company = insert(:company)
      %{id: shipper_id} = shipper = insert(:shipper, location: build(:location, company: company))

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^hidden_driver_by_company_id,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "Consistently late"
              }} =
               Drivers.hide_customer_matches(
                 hidden_driver_by_company,
                 company,
                 "Consistently late"
               )

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^hidden_driver_by_shipper_id,
                company_id: nil,
                shipper_id: ^shipper_id,
                reason: "Consistently late"
              }} =
               Drivers.hide_customer_matches(
                 hidden_driver_by_shipper,
                 shipper,
                 "Consistently late"
               )

      Drivers.update_current_location(driver, chris_house_point())
      Drivers.update_current_location(driver2, chris_house_point())
      Drivers.update_current_location(hidden_driver_by_company, chris_house_point())
      Drivers.update_current_location(hidden_driver_by_shipper, chris_house_point())

      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address, shipper: shipper)
      {:ok, sent_notifications} = DriverNotification.send_available_match_notifications(match, 30)

      assert Enum.count(sent_notifications) == 2
    end

    # NOTE: We are limited to excluding failed notifications in asynchronous notifications
    # TODO: Reinstate
    # test "one_signal errors do not cause other notifications to fail" do
    #   driver =
    #     insert(:driver,
    #       current_location:
    #         build(:driver_location, geo_location: chris_house_point(), driver: nil)
    #     )

    #   device = build(:device, player_id: "bad", driver_id: driver.id)
    #   driver = set_driver_default_device(driver, device)

    #   insert(:driver_location, geo_location: chris_house_point(), driver: driver)
    #   %{driver: driver2} = insert(:driver_location, geo_location: chris_house_point())
    #   driver2 = set_driver_default_device(driver2)

    #   Drivers.update_current_location(driver2, chris_house_point())
    #   gaslight_address = build(:address, geo_location: gaslight_point())
    #   match = insert(:match, origin_address: gaslight_address)
    #   {:ok, sent_notifications} = DriverNotification.send_available_match_notifications(match, 30)
    #   assert Enum.count(sent_notifications) == 1
    # end

    test "drivers with previous sent notifications are excluded" do
      driver = %{id: driver_id} = insert(:driver) |> set_driver_default_device()

      Drivers.update_current_location(driver, chris_house_point())

      gaslight_address = build(:address, geo_location: gaslight_point())
      match = insert(:match, origin_address: gaslight_address)

      assert {:ok, [%{driver_id: ^driver_id}]} =
               DriverNotification.send_available_match_notifications(match, 30)

      assert {:ok, []} = DriverNotification.send_available_match_notifications(match, 30)
    end

    test "notifies drivers with pallet jack for matches that require one" do
      box_truck_driver_with_pallet_jack =
        insert(:driver, vehicles: [build(:box_truck, pallet_jack: true)])

      %Driver{id: box_truck_driver_with_pallet_jack_id} =
        set_driver_default_device(box_truck_driver_with_pallet_jack)

      Drivers.update_current_location(box_truck_driver_with_pallet_jack, gaslight_point())

      insert(:driver_location,
        geo_location: gaslight_point(),
        driver: box_truck_driver_with_pallet_jack
      )

      box_truck_driver_without_pallet_jack =
        insert(:driver, vehicles: [build(:box_truck, pallet_jack: false)])

      Drivers.update_current_location(
        box_truck_driver_without_pallet_jack,
        gaslight_point()
      )

      insert(:driver_location,
        geo_location: gaslight_point(),
        driver: box_truck_driver_without_pallet_jack
      )

      cargo_van_driver = insert(:driver, vehicles: [build(:cargo_van)])

      Drivers.update_current_location(cargo_van_driver, gaslight_point())
      insert(:driver_location, geo_location: gaslight_point(), driver: cargo_van_driver)

      box_truck_with_pallet_jack_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:box_truck),
          origin_address: insert(:address, geo_location: findlay_market_point()),
          match_stops: [build(:match_stop, needs_pallet_jack: true)]
        )

      assert {:ok, [%SentNotification{driver_id: ^box_truck_driver_with_pallet_jack_id}]} =
               DriverNotification.send_available_match_notifications(
                 box_truck_with_pallet_jack_match,
                 30
               )
    end

    test "notifies drivers with lift_gate for matches that require lift_gate load_unload method" do
      box_truck_driver_with_lift_gate =
        insert(:driver, vehicles: [build(:box_truck, lift_gate: true)])

      %Driver{id: box_truck_driver_with_lift_gate_id} =
        set_driver_default_device(box_truck_driver_with_lift_gate)

      Drivers.update_current_location(box_truck_driver_with_lift_gate, gaslight_point())

      insert(:driver_location,
        geo_location: gaslight_point(),
        driver: box_truck_driver_with_lift_gate
      )

      box_truck_driver_without_lift_gate =
        insert(:driver, vehicles: [build(:box_truck, lift_gate: false)])

      Drivers.update_current_location(box_truck_driver_without_lift_gate, gaslight_point())

      insert(:driver_location,
        geo_location: gaslight_point(),
        driver: box_truck_driver_without_lift_gate
      )

      cargo_van_driver = insert(:driver, vehicles: [build(:cargo_van)])

      Drivers.update_current_location(cargo_van_driver, gaslight_point())
      insert(:driver_location, geo_location: gaslight_point(), driver: cargo_van_driver)

      box_truck_with_lift_gate_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:box_truck),
          origin_address: insert(:address, geo_location: findlay_market_point()),
          match_stops: [build(:match_stop)],
          unload_method: :lift_gate
        )

      assert {:ok, [%SentNotification{driver_id: ^box_truck_driver_with_lift_gate_id}]} =
               DriverNotification.send_available_match_notifications(
                 box_truck_with_lift_gate_match,
                 30
               )
    end

    test "ensure box truck drivers only see notifications for box truck matches" do
      box_truck_driver_with_lift_gate =
        insert(:driver, vehicles: [build(:box_truck, lift_gate: true)])

      Drivers.update_current_location(box_truck_driver_with_lift_gate, gaslight_point())

      insert(:driver_location,
        geo_location: gaslight_point(),
        driver: box_truck_driver_with_lift_gate
      )

      cargo_van_match =
        insert(:assigning_driver_match,
          vehicle_class: Shipment.vehicle_class(:cargo_van),
          origin_address: insert(:address, geo_location: findlay_market_point()),
          driver: nil
        )

      assert {:ok, []} =
               DriverNotification.send_available_match_notifications(
                 cargo_van_match,
                 30
               )
    end
  end

  describe "send_available_batch_notifications" do
    test "drivers in multistop schedule that haven't been notified should be notified" do
      %DeliveryBatch{
        matches: [
          %{
            schedule: %{
              drivers: [driver | _]
            }
          }
          | _
        ]
      } =
        batch =
        insert(:delivery_batch_completed)
        |> Repo.preload(matches: [schedule: [:drivers]])

      Drivers.update_current_location(driver, chris_house_point())

      insert(:driver_location, geo_location: chris_house_point(), driver: driver)
      driver = set_driver_default_device(driver)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_available_batch_notifications(batch, 30)

      %SentNotification{
        driver: %{id: driver_id},
        delivery_batch: %{id: batch_id},
        external_id: external_id
      } =
        Repo.get!(SentNotification, sent_notification_id)
        |> Repo.preload([:driver, :delivery_batch])

      assert driver.id == driver_id
      assert batch.id == batch_id
      assert String.length(external_id) > 0
    end

    test "drivers in radius for that haven't been notified should be notified when no schedule" do
      batch =
        insert(:delivery_batch_completed, location: nil)
        |> Repo.preload([:matches])

      driver = insert(:driver)
      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, chris_house_point())

      insert(:driver_location, geo_location: chris_house_point(), driver: driver)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_available_batch_notifications(batch, 30)

      %SentNotification{
        driver: %{id: driver_id},
        delivery_batch: %{id: batch_id},
        external_id: external_id
      } =
        Repo.get!(SentNotification, sent_notification_id)
        |> Repo.preload([:driver, :delivery_batch])

      assert driver.id == driver_id
      assert batch.id == batch_id
      assert String.length(external_id) > 0
    end

    test "drivers not in multistop schedule that haven't been notified should not be notified" do
      driver = insert(:driver, fleet_opt_state: "opted_in")
      Drivers.update_current_location(driver, chris_house_point())
      insert(:driver_location, driver: driver, geo_location: chris_house_point())
      batch = insert(:delivery_batch_completed)
      assert {:ok, []} = DriverNotification.send_available_batch_notifications(batch, 30)
    end
  end

  describe "send_fleet_opt_notification" do
    test "drivers within radius that haven't been notified should be notified" do
      driver = insert(:driver, fleet_opt_state: "opted_in")
      driver = set_driver_default_device(driver)

      Drivers.update_current_location(driver, chris_house_point())
      insert(:driver_location, geo_location: chris_house_point(), driver: driver)

      schedule = insert(:schedule)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)

      %SentNotification{
        driver: %{id: driver_id},
        schedule: %{id: schedule_id},
        external_id: external_id
      } = Repo.get!(SentNotification, sent_notification_id) |> Repo.preload([:driver, :schedule])

      assert driver.id == driver_id
      assert schedule.id == schedule_id
      assert String.length(external_id) > 0
    end

    test "drivers within radius but not opted in should not be notified" do
      driver = insert(:driver, fleet_opt_state: "opted_out")
      Drivers.update_current_location(driver, chris_house_point())
      insert(:driver_location, driver: driver, geo_location: chris_house_point())

      schedule = insert(:schedule)

      {:ok, []} = DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)
    end

    test "drivers within radius but already in fleet should not be notified" do
      driver = insert(:driver, fleet_opt_state: "opted_in")

      Drivers.update_current_location(driver, chris_house_point())
      insert(:driver_location, driver: driver, geo_location: chris_house_point())

      schedule = insert(:schedule, drivers: [driver])

      {:ok, []} = DriverNotification.send_fleet_opportunity_notifications(schedule, 30, false)
    end

    test "drivers opted in but outside radius should not be notified" do
      driver = insert(:driver, fleet_opt_state: "opted_in")

      Drivers.update_current_location(driver, chicago_point())
      insert(:driver_location, driver: driver, geo_location: chicago_point())

      schedule = insert(:schedule)

      {:ok, []} = DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)
    end

    test "drivers with previous sent notifications for this schedule are excluded" do
      driver = insert(:driver, fleet_opt_state: "opted_in")
      driver = set_driver_default_device(driver)
      Drivers.update_current_location(driver, chris_house_point())
      insert(:driver_location, driver: driver, geo_location: chris_house_point())
      schedule = insert(:schedule)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)

      %SentNotification{} = Repo.get!(SentNotification, sent_notification_id)

      insert(:driver_location, driver: driver, geo_location: chris_house_point())

      assert {:ok, []} =
               DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)
    end

    test "drivers with previous sent notifications are included when exclude notified is false" do
      driver = insert(:driver, fleet_opt_state: "opted_in")
      driver = set_driver_default_device(driver)
      Drivers.update_current_location(driver, chris_house_point())
      insert(:driver_location, driver: driver, geo_location: chris_house_point())
      schedule = insert(:schedule)

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_fleet_opportunity_notifications(schedule, 30, false)

      %SentNotification{} = Repo.get!(SentNotification, sent_notification_id)

      insert(:driver_location, driver: driver, geo_location: chris_house_point())

      {:ok, [%SentNotification{id: sent_notification_id}]} =
        DriverNotification.send_fleet_opportunity_notifications(schedule, 30, false)

      %SentNotification{} = Repo.get!(SentNotification, sent_notification_id)

      insert(:driver_location, driver: driver, geo_location: chris_house_point())
    end

    test "drivers with old location inside radius but current location outside radius should not get notified" do
      driver = insert(:driver, fleet_opt_state: "opted_in")

      chris_house_location =
        insert(:driver_location, geo_location: chris_house_point(), driver: driver)

      Drivers.update_current_location(driver, chris_house_point())
      # travel back in time and have inserted this yesterday
      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600)
      update_query = from(dl in DriverLocation, where: dl.id == ^chris_house_location.id)
      Repo.update_all(update_query, set: [inserted_at: yesterday])

      insert(:driver_location, geo_location: chicago_point(), driver: driver)
      Drivers.update_current_location(driver, chicago_point())
      schedule = insert(:schedule)

      assert {:ok, []} =
               DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)
    end

    test "does not notify company's blocked drivers" do
      driver = insert(:driver, fleet_opt_state: "opted_in")

      %{driver: %{id: hidden_driver_id} = hidden_driver} =
        insert(:driver_location, driver: driver, geo_location: chris_house_point())

      %{id: company_id} = company = insert(:company)
      location = insert(:location, company: company)

      Drivers.update_current_location(driver, chris_house_point())

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^hidden_driver_id,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "Consistently late"
              }} = Drivers.hide_customer_matches(hidden_driver, company, "Consistently late")

      schedule = insert(:schedule, location: location)

      assert {:ok, []} =
               DriverNotification.send_fleet_opportunity_notifications(schedule, 30, true)
    end
  end

  describe "send_documents_approved" do
    test "fails when driver has no default device" do
      driver = insert(:driver)

      assert {:ok, {:error, _, _}} = DriverNotification.send_documents_approved(driver)
    end

    test "success when driver has a default device" do
      driver = insert(:driver)
      device = insert(:device, driver: driver)
      set_driver_default_device(driver, device)

      assert {:ok, _sent} = DriverNotification.send_documents_approved(driver)
    end
  end

  describe "test documents approval and rejection notifications" do
    test "send_documents_rejected/1 fails when driver has no default device" do
      driver = insert(:driver)

      assert {:ok, {:error, _, _}} = DriverNotification.send_documents_rejected(driver)
    end

    test "send_documents_rejected/1 success when driver has a default device" do
      driver = insert(:driver)
      device = insert(:device, driver: driver)
      set_driver_default_device(driver, device)

      assert {:ok, _sent} = DriverNotification.send_documents_rejected(driver)
    end

    test "send_rejected_documents_email/1 fails when driver has no default device" do
      driver = insert(:driver)

      assert %Bamboo.Email{} = DriverNotification.send_rejected_documents_email(driver)
    end

    test "send_approval_letter_email/1" do
      driver = insert(:driver)

      assert %Bamboo.Email{} = DriverNotification.send_approval_letter_email(driver)
    end

    test "send_rejection_letter_email/1" do
      driver = insert(:driver)

      assert %Bamboo.Email{} = DriverNotification.send_rejection_letter_email(driver)
    end

    test "send_approved_documents_email" do
      driver = insert(:driver)

      assert %Bamboo.Email{} = DriverNotification.send_approved_documents_email(driver)
    end
  end

  test "test driver removed or reassigned" do
    %{driver: driver} = match = insert(:match, driver: build(:driver))
    driver = set_driver_default_device(driver)

    assert {:ok, _sent} = DriverNotification.send_removed_from_match_notification(driver, match)
  end
end
