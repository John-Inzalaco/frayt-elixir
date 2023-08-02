defmodule FraytElixir.DriversTest do
  use FraytElixir.DataCase
  use Bamboo.Test

  import FraytElixir.Factory
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  alias FraytElixir.Drivers

  alias FraytElixir.Drivers.{
    Driver,
    DriverLocation,
    Vehicle,
    DriverMetrics,
    HiddenCustomer
  }

  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Repo
  alias FraytElixir.Email
  alias FraytElixir.Shipment.{Match, HiddenMatch, MatchStop}
  alias FraytElixir.Shipment
  alias FraytElixir.Accounts.User
  alias FraytElixir.Test.FakeSlack
  alias ExPhoneNumber.Model.PhoneNumber
  alias FraytElixirWeb.Test.FileHelper

  setup :start_match_supervisor

  setup do
    FakeSlack.clear_messages()
    start_match_webhook_sender(self())
  end

  describe "get_match" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    end

    test "should list matches even though they are locked for update" do
      match = insert(:assigning_driver_match, driver: nil)
      [driver1, driver2] = insert_list(2, :driver_with_wallet)

      parent = self()

      _task1 =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          Drivers.accept_match(match, driver1)
        end)

      task2 =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          FraytElixir.Shipment.get_match(match.id)
        end)

      _task3 =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())

          assert_raise Ecto.StaleEntryError, fn ->
            Drivers.accept_match(match, driver2)
          end
        end)

      assert match.id == Task.await(task2) |> Map.get(:id)
    end
  end

  describe "accept_match/3" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    end

    test "should allow only one driver to accept a match" do
      match = insert(:assigning_driver_match, driver: nil)
      [driver1, driver2] = insert_list(2, :driver_with_wallet)
      parent = self()

      task1 =
        Task.async(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          Drivers.accept_match(match, driver1)
        end)

      task2 =
        Task.async(fn ->
          Drivers.accept_match(match, driver2)
        end)

      results =
        [task1, task2]
        |> Enum.map(fn task ->
          case Task.await(task) do
            {:ok, _} ->
              :ok

            _ ->
              :error
          end
        end)

      assert 1 == Enum.filter(results, &(&1 == :ok)) |> Enum.count()
      assert 1 == Enum.filter(results, &(&1 == :error)) |> Enum.count()
    end
  end

  describe "drivers" do
    @valid_attrs %{
      first_name: "some first_name",
      last_name: "some last_name",
      license_number: "some license_number",
      license_state: "some license_state",
      phone_number: "+1 513-555-5555",
      english_proficiency: "advanced",
      address: %{
        address: "6950 Pebble Brook Way",
        city: "Rocky Mount",
        state: "NC",
        zip: "27804"
      },
      vehicle_class: "car",
      user: %{
        email: "some@email.com"
      }
    }
    @update_attrs %{
      first_name: "some updated first_name",
      last_name: "some updated last_name",
      license_number: "some updated license_number",
      license_state: "some updated license_state",
      phone_number: "+15135551111",
      ssn: "000-00-0000"
    }
    @invalid_attrs %{
      first_name: nil,
      last_name: nil,
      license_number: nil,
      license_state: nil,
      phone_number: nil,
      ssn: "00-00-000000",
      vehicle_class: "car"
    }

    test "list_drivers/1 preloads specified assocs" do
      insert(:driver)

      assert {[driver], 1} =
               Drivers.list_drivers(
                 %{
                   page: 0,
                   per_page: 2,
                   order: :asc,
                   order_by: :driver_name,
                   query: nil
                 },
                 [:user]
               )

      assert %Driver{user: %User{}, address: %Ecto.Association.NotLoaded{}} = driver
    end

    test "list_drivers/1 filters properly by name" do
      insert(:driver, first_name: "Driver 1")
      insert(:driver, first_name: "Driver 2")
      insert(:driver, first_name: "DaDASDFA")

      drivers =
        Drivers.list_drivers(%{
          page: 0,
          per_page: 3,
          order: :asc,
          order_by: :driver_name,
          query: nil
        })
        |> elem(0)

      assert Enum.count(drivers) == 3

      drivers =
        Drivers.list_drivers(%{
          page: 0,
          per_page: 2,
          order: :asc,
          order_by: :driver_name,
          query: "Driver 2"
        })
        |> elem(0)

      assert [%{first_name: "Driver 2"}] = drivers

      drivers =
        Drivers.list_drivers(%{
          page: 0,
          per_page: 2,
          order: :asc,
          order_by: :driver_name,
          query: "Driver 1"
        })
        |> elem(0)

      assert [%{first_name: "Driver 1"}] = drivers

      drivers =
        Drivers.list_drivers(%{
          page: 0,
          per_page: 2,
          order: :asc,
          order_by: :driver_name,
          query: "DaDASDFA"
        })
        |> elem(0)

      assert [%{first_name: "DaDASDFA"}] = drivers
    end

    test "list_drivers/1 filters by state" do
      insert(:driver, state: :registered)
      insert(:driver, state: :approved)
      insert(:driver, state: :disabled)

      assert {[%Driver{state: :registered}], 1} =
               Drivers.list_drivers(%{state: :registered, order: :asc})

      assert {[%Driver{state: :approved}], 1} =
               Drivers.list_drivers(%{state: :approved, order: :asc})

      assert {[%Driver{state: :disabled}], 1} =
               Drivers.list_drivers(%{state: :disabled, order: :asc})
    end

    test "get_driver!/1 returns the driver with given id" do
      driver = insert(:driver)
      fetched_driver = Drivers.get_driver!(driver.id)
      assert fetched_driver.id == driver.id
    end

    test "get_active_matches/1" do
      driver = insert(:driver)
      driver2 = insert(:driver)
      insert(:match, state: "canceled", driver: driver)
      insert(:match, state: "accepted", driver: driver)
      insert(:match, state: "completed", driver: driver)
      insert(:match, state: "en_route_to_pickup", driver: driver)
      insert(:match, state: "completed", driver: driver2)
      insert(:match, state: "en_route_to_pickup", driver: driver2)

      assert 2 == Drivers.active_matches_count(driver.id)

      assert 1 == Drivers.active_matches_count(driver2.id)
    end

    test "create_driver/1 with valid data creates a driver" do
      password = "123456"
      market = insert(:market, currently_hiring: [:car, :cargo_van, :midsize, :box_truck])

      driver_attrs =
        @valid_attrs
        |> Map.put(:user, %{email: "bilbo@bagend.com", password: password})
        |> Map.put(:market_id, market.id)

      assert {:ok, driver} = Drivers.create_driver(driver_attrs)

      %Driver{address: address} = Repo.get_by(Driver, id: driver.id) |> Repo.preload([:address])

      assert driver.user.email == "bilbo@bagend.com"
      assert driver.user.hashed_password != password
      assert driver.first_name == "some first_name"
      assert driver.last_name == "some last_name"
      assert driver.license_number == "some license_number"
      assert driver.license_state == "some license_state"
      assert driver.english_proficiency == :advanced
      assert driver.market_id == market.id
      assert driver.phone_number == %PhoneNumber{country_code: 1, national_number: 5_135_555_555}
      assert %DriverMetrics{rating: 0.0, rated_matches: 0, completed_matches: 0} = driver.metrics
      assert address.formatted_address == "6950 Pebble Brook Way, Rocky Mount, NC 27804"
      assert %Geo.Point{coordinates: {_, _}} = address.geo_location
    end

    test "create_driver/1 without agreements or metrics doesn't fail" do
      password = "123456"
      market = insert(:market, currently_hiring: [:car, :cargo_van, :midsize, :box_truck])

      driver_attrs =
        @valid_attrs
        |> Map.put(:user, %{email: "bilbo@bagend.com", password: password})
        |> Map.put(:agreements, nil)
        |> Map.put(:metrics, nil)
        |> Map.put(:market_id, market.id)

      assert {:ok, _driver} = Drivers.create_driver(driver_attrs)
    end

    test "create_driver/1 with invalid data returns error changeset" do
      market = insert(:market, currently_hiring: [:car, :cargo_van, :midsize, :box_truck])

      driver_attrs = Map.put(@invalid_attrs, :market_id, market.id)

      assert {:error,
              %Ecto.Changeset{
                errors: errors
              }} = Drivers.create_driver(driver_attrs)

      assert {_message, [{:count, 9}, {:validation, :length}, {:kind, :is}, {:type, :string}]} =
               errors[:ssn]

      assert {_, [validation: :required]} = errors[:phone_number]
    end

    test "update_driver/2 with valid data updates the driver" do
      driver = insert(:driver)
      assert {:ok, %Driver{} = driver} = Drivers.update_driver(driver, @update_attrs)
      assert driver.first_name == "some updated first_name"
      assert driver.last_name == "some updated last_name"
      assert driver.license_number == "some updated license_number"
      assert driver.license_state == "some updated license_state"
      assert driver.ssn == "000000000"

      assert driver.phone_number == %PhoneNumber{
               country_code: 1,
               national_number: 5_135_551_111
             }
    end

    test "update_driver/2 with invalid data returns error changeset" do
      driver = insert(:driver)
      assert {:error, %Ecto.Changeset{}} = Drivers.update_driver(driver, @invalid_attrs)
      fetched_driver = Drivers.get_driver!(driver.id)
      assert driver.id == fetched_driver.id
    end

    test "update_driver/2 active_match_limit property do not allows zero as value" do
      driver = insert(:driver)

      {:error, %Ecto.Changeset{errors: [error]}} =
        Drivers.update_driver(driver, %{active_match_limit: 0})

      assert {:active_match_limit,
              {"must be greater then 0 or empty/default",
               [validation: :number, kind: :not_equal_to, number: 0]}} == error
    end

    test "update_driver/2 active_match_limit property allows nil as value or number greater than 0" do
      driver = insert(:driver)

      assert {:ok, _cs} = Drivers.update_driver(driver, %{active_match_limit: nil})
      assert {:ok, _cs} = Drivers.update_driver(driver, %{active_match_limit: 1})
    end

    test "update_driver_identity/2 with valid data updates the driver" do
      driver = insert(:driver)

      assert {:ok, %Driver{} = driver} =
               Drivers.update_driver_identity(driver, %{
                 ssn: "000-00-0010",
                 birthdate: ~D[1901-01-01]
               })

      assert driver.ssn == "000000010"
      assert driver.birthdate
    end

    test "update_driver/2 with valid account fields updates the driver" do
      account_params = %{
        email: "email@example.com",
        first_name: "Billy",
        last_name: "Bob",
        phone_number: "+15132223333"
      }

      driver = insert(:driver)

      address_params = %{
        id: driver.address_id,
        address: "131 E 14th Street",
        city: "Cincinnati",
        state: "Ohio",
        zip: "45202"
      }

      account_params = account_params |> Map.put(:address, address_params)

      assert {:ok, %Driver{}} = Drivers.update_driver(driver, account_params)
      fetched_driver = Drivers.get_driver!(driver.id) |> Repo.preload(:address)
      assert fetched_driver.address.state == "Ohio"
    end

    test "update_driver/2 with valid account fields updates the driver when they have no address yet" do
      account_params = %{
        email: "email@example.com",
        first_name: "Billy",
        last_name: "Bob",
        phone_number: "+15132223333"
      }

      driver = insert(:driver, address: nil)

      address_params = %{
        id: driver.address_id,
        address: "708 Walnut St",
        city: "Cincinnati",
        state: "Ohio",
        zip: "45202"
      }

      account_params = Map.put(account_params, :address, address_params)

      assert {:ok, %Driver{address: address}} = Drivers.update_driver(driver, account_params)

      assert address.state == "Ohio"
      assert %Geo.Point{} = address.geo_location
    end

    test "get_driver_for_user/1 returns a driver" do
      %{id: driver_id, user: user} = insert(:driver)

      assert {:ok, %Driver{id: ^driver_id}} = Drivers.get_driver_for_user(user)
    end

    test "get_driver_for_user/1 when user is a shipper returns an error" do
      %{user: user} = insert(:shipper)

      assert {:error, :invalid_user, _} = Drivers.get_driver_for_user(user)
    end

    test "list_capacity/1 returns proper list of drivers filtered by vehicle type" do
      driver1 = insert(:driver, vehicles: [build(:vehicle, vehicle_class: 1)])

      driver2 =
        insert(:driver,
          vehicles: [build(:vehicle, vehicle_class: 2), build(:vehicle, vehicle_class: 1)]
        )

      driver3 = insert(:driver, vehicles: [build(:vehicle, vehicle_class: 3)])

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: chris_house_point(),
          search_radius: nil,
          pickup_address: "",
          driver_location: :address,
          vehicle_types: [1]
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert driver1.id in drivers
      assert driver2.id in drivers
      assert Enum.count(drivers) == 2

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: chris_house_point(),
          search_radius: nil,
          pickup_address: "",
          driver_location: :address,
          vehicle_types: [1, 2, 3]
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert driver1.id in drivers
      assert driver2.id in drivers
      assert driver3.id in drivers
      assert Enum.count(drivers) == 3

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: chris_house_point(),
          search_radius: nil,
          pickup_address: "",
          driver_location: :address,
          vehicle_types: [2, 3]
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert driver2.id in drivers
      assert driver3.id in drivers
      assert Enum.count(drivers) == 2

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: chris_house_point(),
          search_radius: nil,
          pickup_address: "",
          driver_location: :address,
          vehicle_types: [1, 2]
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert driver2.id in drivers
      assert driver1.id in drivers
      assert Enum.count(drivers) == 2
    end

    test "list_capacity filters and orders by distance from pickup address for last seen" do
      chris_driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: chris_house_point())
        )

      findlay_driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: findlay_market_point())
        )

      chicago_driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: chicago_point())
        )

      gaslight_driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point())
        )

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :current_location,
          vehicle_types: [1, 2, 3],
          search_radius: 300,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert Enum.count(drivers) == 4

      assert [
               gaslight_driver.id,
               findlay_driver.id,
               chris_driver.id,
               chicago_driver.id
             ] == drivers

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :current_location,
          vehicle_types: [1, 2, 3],
          search_radius: 50,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert [
               gaslight_driver.id,
               findlay_driver.id,
               chris_driver.id
             ] == drivers

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :current_location,
          vehicle_types: [1, 2, 3],
          search_radius: 10,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert [gaslight_driver.id, findlay_driver.id] == drivers
    end

    test "list_capacity when search radius is not set" do
      driver_1 = insert(:driver, address: build(:address, geo_location: gaslight_point()))
      driver_2 = insert(:driver, address: build(:address, geo_location: findlay_market_point()))

      driver_3 =
        insert(:driver,
          address: build(:address, geo_location: chris_house_point()),
          inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now(), 120)
        )

      driver_4 = insert(:driver, address: build(:address, geo_location: chicago_point()))
      all_drivers = [driver_1.id, driver_2.id, driver_3.id, driver_4.id]

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: nil,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert Enum.count(drivers) == 4
      assert drivers == all_drivers
    end

    test "list_capacity filters and order by distance from pickup address for home" do
      chris_house = insert(:driver, address: build(:address, geo_location: chris_house_point()))

      findlay_market =
        insert(:driver, address: build(:address, geo_location: findlay_market_point()))

      chicago =
        insert(:driver,
          address: build(:address, geo_location: chicago_point()),
          inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now(), 120)
        )

      gaslight = insert(:driver, address: build(:address, geo_location: gaslight_point()))

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: 300,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert Enum.count(drivers) == 4
      assert [gaslight.id, findlay_market.id, chris_house.id, chicago.id] == drivers

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: 50,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert [gaslight.id, findlay_market.id, chris_house.id] == drivers

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: 10,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert [gaslight.id, findlay_market.id] == drivers
    end

    test "list_capacity when search radius is not set still sorts by distance from pickup" do
      chris_house = insert(:driver, address: build(:address, geo_location: chris_house_point()))
      chicago = insert(:driver, address: build(:address, geo_location: chicago_point()))
      gaslight = insert(:driver, address: build(:address, geo_location: gaslight_point()))
      unknown = insert(:driver, address: nil)

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: nil,
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: nil,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert Enum.count(drivers) == 4
      assert [gaslight.id, chris_house.id, chicago.id, unknown.id] == drivers
    end

    test "list_capacity with a driver email" do
      insert(:driver, address: build(:address, geo_location: chris_house_point()))
      insert(:driver, address: build(:address, geo_location: chicago_point()))
      gaslight = insert(:driver, address: build(:address, geo_location: gaslight_point()))
      insert(:driver, address: nil)

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: gaslight.user.email,
          pickup_point: nil,
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: nil,
          pickup_address: "520 Vine St., Cincinnati, OH"
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert Enum.count(drivers) == 1
      assert [gaslight.id] == drivers
    end

    test "list_capacity with a query filters out unapproved drivers" do
      insert_list(3, :driver, state: "approved")
      insert_list(2, :driver, state: "registered")
      %{id: id1} = insert(:driver, state: "disabled")
      %{id: id2} = insert(:driver, state: "rejected")

      drivers =
        Drivers.list_capacity(%{
          per_page: 10,
          page: 0,
          query: nil,
          pickup_point: chris_house_point(),
          driver_location: :address,
          vehicle_types: [1, 2, 3],
          search_radius: nil,
          pickup_address: ""
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert Enum.count(drivers) == 5
      refute id1 in drivers
      refute id2 in drivers
    end

    test "list_capacity_drivers/2" do
      %Driver{id: driver_id} = insert(:driver)

      pickup_point = chris_house_point()

      assert {:ok, drivers, %{pickup_point: ^pickup_point}} =
               Drivers.list_capacity_drivers(%{
                 query: nil,
                 pickup_point: pickup_point,
                 driver_location: :address,
                 vehicle_types: [1, 2, 3],
                 search_radius: nil,
                 pickup_address: ""
               })

      assert [%Driver{id: ^driver_id}] = drivers
    end

    test "list_capacity_drivers/2 limits number of drivers" do
      insert_list(10, :driver)

      assert {:ok, [%Driver{}, %Driver{}, %Driver{}, %Driver{}, %Driver{}, %Driver{}],
              _updated_state} =
               Drivers.list_capacity_drivers(
                 %{
                   query: nil,
                   pickup_point: chris_house_point(),
                   driver_location: :address,
                   vehicle_types: [1, 2, 3],
                   search_radius: nil,
                   pickup_address: ""
                 },
                 6
               )
    end

    test "list_capacity_drivers/2 filters out drivers who have opted out" do
      insert_list(10, :driver)
      insert_list(5, :driver, sms_opt_out: true)

      assert {:ok, drivers, _updated_state} =
               Drivers.list_capacity_drivers(%{
                 query: nil,
                 pickup_point: chris_house_point(),
                 driver_location: :address,
                 vehicle_types: [1, 2, 3],
                 search_radius: nil,
                 pickup_address: ""
               })

      assert drivers |> Enum.all?(&(&1.sms_opt_out == false))
      assert drivers |> Enum.count() == 10
    end

    test "list_capacity_drivers/2 returns error" do
      insert_list(10, :driver)

      assert {:error, :address_not_found} =
               Drivers.list_capacity_drivers(%{
                 query: nil,
                 pickup_point: :not_found,
                 driver_location: :address,
                 vehicle_types: [1, 2, 3],
                 search_radius: nil,
                 pickup_address: ""
               })
    end
  end

  describe "list_past_drivers_for_shipper/1" do
    test "returns a list of drivers with completed matches with shipper" do
      shipper = insert(:shipper)
      expected_driver_count = 3

      expected_driver_ids =
        for _ <- 1..expected_driver_count do
          %{driver: %{id: driver_id}} = insert(:completed_match, shipper: shipper)

          driver_id
        end

      drivers_ids =
        shipper.id
        |> Drivers.list_past_drivers_for_shipper()
        |> Enum.map(& &1.id)

      assert length(drivers_ids) == expected_driver_count
      assert expected_driver_ids -- drivers_ids == []
    end

    test "does not include drivers without a completed match" do
      shipper = insert(:shipper)

      insert(:canceled_match, shipper: shipper)

      assert [] = Drivers.list_past_drivers_for_shipper(shipper.id)
    end

    test "does not include blocked drivers" do
      company = insert(:company)
      %{id: shipper_id} = shipper = insert(:shipper, location: build(:location, company: company))

      %{driver: %{id: driver_id_1}} =
        insert(:completed_match, driver: build(:driver), shipper: shipper)

      %{driver: %{id: driver_id_2}} =
        insert(:completed_match, driver: build(:driver), shipper: shipper)

      hidden_driver = insert(:driver)

      %{driver: %{id: hidden_driver_id}} =
        insert(:completed_match, driver: hidden_driver, shipper: shipper)

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^hidden_driver_id,
                company_id: nil,
                shipper_id: ^shipper_id,
                reason: "Consistently late"
              }} =
               Drivers.hide_customer_matches(
                 hidden_driver,
                 shipper,
                 "Consistently late"
               )

      assert [
               %FraytElixir.Drivers.Driver{id: ^driver_id_2},
               %FraytElixir.Drivers.Driver{id: ^driver_id_1}
             ] = Drivers.list_past_drivers_for_shipper(shipper.id)
    end
  end

  describe "list_drivers_for_shipper/2" do
    test "returns past drivers for a shipper when no filter provided" do
      shipper = insert(:shipper)
      %{driver: %{id: driver_id}} = insert(:completed_match, shipper: shipper)
      _decoy_driver = insert(:driver)

      assert [%{id: ^driver_id}] = Drivers.list_drivers_for_shipper(shipper)
    end

    test "returns driver by email when provided email filter" do
      shipper = insert(:shipper)
      %{id: driver_id} = insert(:driver, user: build(:user, email: "driver@frayt.com"))
      _decoy_driver = insert(:driver)

      assert [%{id: ^driver_id}] =
               Drivers.list_drivers_for_shipper(shipper, %{email: "driver@frayt.com"})
    end
  end

  describe "get_driver_by_email/2" do
    test "returns a driver by email" do
      company = insert(:company)
      %{id: shipper_id} = insert(:shipper, location: build(:location, company: company))

      %{id: driver_id} = insert(:driver, user: build(:user, email: "driver@frayt.com"))
      _decoy_driver = insert(:driver, user: build(:user, email: "other_driver@frayt.com"))

      assert %Driver{id: ^driver_id} =
               Drivers.get_preferred_driver_by_email("driver@frayt.com", shipper_id)
    end

    test "does not return drivers blocked from shipper" do
      %{id: shipper_id} = shipper = insert(:shipper)
      %{user: %{email: driver_email}} = hidden_driver = insert(:driver)
      insert(:hidden_customer, driver: hidden_driver, shipper: shipper)

      assert is_nil(Drivers.get_preferred_driver_by_email(driver_email, shipper_id))
    end

    test "does not return drivers blocked from company" do
      %{id: shipper_id, location: %{company: company}} = insert(:shipper_with_location)
      %{user: %{email: driver_email}} = hidden_driver = insert(:driver)
      insert(:hidden_customer, driver: hidden_driver, company: company)

      assert is_nil(Drivers.get_preferred_driver_by_email(driver_email, shipper_id))
    end
  end

  describe "update_driver_state/3" do
    test "creates a driver state transition WITH a note" do
      driver = insert(:driver, state: :approved)
      notes = "Your documents are invalid."

      assert {:ok, %Driver{state_transitions: state_transitions} = driver} =
               Drivers.update_driver_state(driver, :rejected, notes)

      assert driver.state == :rejected
      refute(Enum.empty?(state_transitions))
      transition = List.first(state_transitions)
      assert transition.notes == notes
    end

    test "creates a driver state transition WITHOUT a note" do
      driver = insert(:driver, state: :pending_approval)

      assert {:ok, %Driver{state_transitions: state_transitions} = driver} =
               Drivers.update_driver_state(driver, :approved)

      assert driver.state == :approved
      refute(Enum.empty?(state_transitions))
    end

    test "unable to change a driver state to the same state it was in before" do
      driver = insert(:driver, state: :approved)

      assert {:error, "invalid driver state transition"} =
               Drivers.update_driver_state(driver, :approved, nil)

      driver = insert(:driver, state: :disabled)

      assert :error = Drivers.disable_driver_account(driver, nil)
    end
  end

  describe "set_initial_password" do
    test "for unregistered driver" do
      driver = insert(:unregistered_driver)
      password = "ABCdef@1"
      password_confirmation = "ABCdef@1"

      assert {:ok, %User{}} =
               Drivers.set_initial_password(driver.user, password, password_confirmation)
    end

    test "for unregistered driver fails if confirmation doesn't match" do
      driver = insert(:unregistered_driver)
      password = "ABC456"
      password_confirmation = "XYZ987"

      assert {:error, changeset} =
               Drivers.set_initial_password(driver.user, password, password_confirmation)

      assert {_msg, [validation: :confirmation]} = changeset.errors[:password_confirmation]
    end

    test "for driver with password fails" do
      driver = insert(:driver)
      password = "ABC456"
      password_confirmation = "ABC456"

      assert {:error, changeset} =
               Drivers.set_initial_password(driver.user, password, password_confirmation)

      assert {_msg, [validation: :password_not_set]} = changeset.errors[:password]
    end
  end

  describe "change_password" do
    test "changes password" do
      driver = insert(:driver)

      attrs = %{
        current: "password",
        new: "ABCD@123",
        confirmation: "ABCD@123"
      }

      assert {:ok, %User{}} = Drivers.change_password(driver.user, attrs)
    end

    test "fails when password is too short" do
      driver = insert(:driver)

      attrs = %{
        current: "password",
        new: "Pass@5",
        confirmation: "Pass@5"
      }

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Drivers.change_password(driver.user, attrs)

      assert {_, [count: 8, validation: :length, kind: :min, type: :string]} = errors[:password]
    end

    test "fails when password does not contain special characters" do
      driver = insert(:driver)

      attrs = %{
        current: "password",
        new: "Password5",
        confirmation: "Password5"
      }

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Drivers.change_password(driver.user, attrs)

      assert {"must contain a special character", _} = errors[:password]
    end

    test "fails when password does not contain a number" do
      driver = insert(:driver)

      attrs = %{
        current: "password",
        new: "Password%",
        confirmation: "Password%"
      }

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Drivers.change_password(driver.user, attrs)

      assert {"must contain a number", _} = errors[:password]
    end

    test "fails when password does not contain a letter" do
      driver = insert(:driver)

      attrs = %{
        current: "password",
        new: "'123%63&|",
        confirmation: "'123%63&|"
      }

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Drivers.change_password(driver.user, attrs)

      assert {"must contain a letter", _} = errors[:password]
    end

    test "fails when password does not match confirmation" do
      driver = insert(:driver)

      attrs = %{
        current: "password",
        new: "ABC456",
        confirmation: "ABCDEF"
      }

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Drivers.change_password(driver.user, attrs)

      assert {_, [validation: :confirmation]} = errors[:password_confirmation]
    end

    test "fails when current password is invalid" do
      driver = insert(:driver)

      attrs = %{
        current: "password1",
        new: "ABC456",
        confirmation: "ABC456"
      }

      assert {:error, :invalid_password} = Drivers.change_password(driver.user, attrs)
    end
  end

  describe "list_available_matches_for_driver" do
    test "finds matches from notifications sent within the past week that are in the assigning_driver state" do
      driver = insert(:driver)
      %Match{id: match_id} = match = insert(:match, state: :assigning_driver)

      insert(:sent_notification, match: match, driver: driver)

      assert [%Match{id: ^match_id}] = Drivers.list_available_matches_for_driver(driver)
    end

    test "doesn't return duplicates for multiple notifications" do
      driver = insert(:driver)
      %Match{id: match_id} = match = insert(:match, state: :assigning_driver)

      insert(:sent_notification,
        match: match,
        driver: driver,
        inserted_at: ~N[2022-11-01 00:00:00]
      )

      insert(:sent_notification, match: match, driver: driver)
      insert(:sent_notification, match: match, driver: driver)

      insert(:sent_notification,
        match: match,
        driver: driver,
        inserted_at: ~N[2022-11-01 00:00:00]
      )

      assert [%Match{id: ^match_id}] = Drivers.list_available_matches_for_driver(driver)
    end

    test "can filter by batch id" do
      driver = insert(:driver)
      batch = insert(:delivery_batch)

      %Match{id: match_id} =
        match = insert(:match, state: :assigning_driver, delivery_batch: batch)

      insert(:sent_notification, match: match, driver: driver)
      insert(:sent_notification, match: build(:match, state: :assigning_driver), driver: driver)

      assert [%Match{id: ^match_id}] = Drivers.list_available_matches_for_driver(driver, batch.id)
    end

    test "ignores notifications over a week old" do
      driver = insert(:driver)
      match = insert(:match, state: :assigning_driver)

      insert(:sent_notification,
        match: match,
        driver: driver,
        inserted_at: ~N[2022-11-01 00:00:00]
      )

      assert [] = Drivers.list_available_matches_for_driver(driver)
    end

    test "ignores accepted matches" do
      driver = insert(:driver)
      match = insert(:match, state: :accepted)

      insert(:sent_notification, match: match, driver: driver)

      assert [] = Drivers.list_available_matches_for_driver(driver)
    end

    test "ignores canceled matches" do
      driver = insert(:driver)
      match = insert(:match, state: :canceled)

      insert(:sent_notification, match: match, driver: driver)

      assert [] = Drivers.list_available_matches_for_driver(driver)
    end

    test "ignores hidden matches" do
      driver = insert(:driver)

      %Match{id: match_id} = match = insert(:match, state: :assigning_driver)

      insert(:sent_notification, match: match, driver: driver)

      assert [%Match{id: ^match_id}] = Drivers.list_available_matches_for_driver(driver)

      assert {:ok, %HiddenMatch{}} = Drivers.reject_match(match, driver)

      assert [] = Drivers.list_available_matches_for_driver(driver)
    end

    test "canceled matches are ignored" do
      driver = insert(:driver_with_wallet)

      match = insert(:assigning_driver_match)
      insert(:sent_notification, match: match, driver: driver)

      assert [%Match{}] = Drivers.list_available_matches_for_driver(driver)
      Drivers.accept_match(match, driver)
      Drivers.cancel_match(match, "my reason")
      assert [] = Drivers.list_available_matches_for_driver(driver)
    end

    test "returns empty array when the driver doesn't have any notifications" do
      driver = insert(:driver)

      insert(:sent_notification, match: build(:match, state: :assigning_driver))

      assert [] = Drivers.list_available_matches_for_driver(driver)
    end

    test "ignores unassigned preferred driver matches" do
      driver = insert(:driver)

      match =
        insert(:match, state: :assigning_driver, platform: :deliver_pro, preferred_driver_id: nil)

      insert(:sent_notification, match: match, driver: driver)

      assert [] = Drivers.list_available_matches_for_driver(driver)
    end
  end

  describe "list_missed_matches_for_driver" do
    alias FraytElixir.Shipment.{MatchState}

    test "finds match within 60 miles from driver's location accepted by different driver within the last 48 hours" do
      driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point(), driver: nil)
        )

      %{match: %{id: match_id}} = insert(:accepted_match_state_transition)
      [%Match{id: ^match_id}] = Drivers.list_missed_matches_for_driver(driver)
    end

    test "finds only matches still in live state" do
      [first_live_enum, second_live_enum | _rest] = MatchState.live_range()

      driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point(), driver: nil)
        )

      %{id: live_missed_match_id} = match = insert(:match, state: second_live_enum)
      insert(:accepted_match_state_transition, match: match)

      insert(:accepted_match_state_transition,
        from: first_live_enum,
        to: second_live_enum,
        match: match
      )

      completed_missed_match = insert(:match, state: :completed)
      insert(:accepted_match_state_transition, match: completed_missed_match)

      insert(:accepted_match_state_transition,
        from: :picked_up,
        to: :completed,
        match: completed_missed_match
      )

      unaccepted_match = insert(:match, state: :scheduled)

      insert(:accepted_match_state_transition,
        from: :pending,
        to: :scheduled,
        match: unaccepted_match
      )

      [%Match{id: ^live_missed_match_id}] = Drivers.list_missed_matches_for_driver(driver)
    end

    test "does not find matches accepted more than 48 hours ago" do
      driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point(), driver: nil)
        )

      three_days_ago = DateTime.utc_now() |> DateTime.add(-3 * 24 * 60 * 60, :second)

      _long_ago_match =
        insert(:accepted_match_state_transition,
          inserted_at: three_days_ago
        )

      assert [] = Drivers.list_missed_matches_for_driver(driver)
    end

    test "does not find matches more than 60 miles from driver's location" do
      driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point(), driver: nil)
        )

      _far_away_match =
        insert(:accepted_match_state_transition,
          match:
            build(:match,
              state: :accepted,
              origin_address: build(:address, geo_location: chicago_point())
            )
        )

      assert [] = Drivers.list_missed_matches_for_driver(driver)
    end

    test "does not find matches which the driver has rejected" do
      driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point(), driver: nil)
        )

      %{match: match} = insert(:accepted_match_state_transition)
      Drivers.reject_match(match, driver)

      assert [] = Drivers.list_missed_matches_for_driver(driver)
    end

    test "returns empty array when the driver doesn't have a current location" do
      driver = insert(:driver)

      insert(:accepted_match_state_transition)

      assert [] = Drivers.list_missed_matches_for_driver(driver)
    end

    test "correctly paginates and orders the matches by their accept date" do
      driver =
        insert(:driver,
          current_location: build(:driver_location, geo_location: gaslight_point(), driver: nil)
        )

      insert(:accepted_match, driver: driver)

      now = DateTime.utc_now()

      missed_matches =
        Enum.map(
          0..9,
          fn index ->
            transition =
              insert(:accepted_match_state_transition,
                inserted_at: DateTime.add(now, -index, :second)
              )

            transition.match
          end
        )

      week_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)

      _week_old_missed_match =
        insert(:accepted_match_state_transition,
          inserted_at: week_ago
        )

      missed_match =
        missed_matches
        |> Enum.at(0)
        |> Repo.preload(:state_transitions)

      retrieved_missed_matches = Drivers.list_missed_matches_for_driver(driver)

      retrieved_missed_match =
        retrieved_missed_matches
        |> Enum.at(0)
        |> Repo.preload(:state_transitions)

      assert (missed_match.state_transitions |> Enum.at(0)).inserted_at ==
               (retrieved_missed_match.state_transitions |> Enum.at(0)).inserted_at

      %Match{id: first_missed_match_id} = missed_matches |> Enum.at(0)
      %Match{id: tenth_missed_match_id} = missed_matches |> Enum.at(9)

      assert %Match{id: ^first_missed_match_id} = retrieved_missed_matches |> Enum.at(0)
      assert %Match{id: ^tenth_missed_match_id} = retrieved_missed_matches |> Enum.at(9)
      assert Enum.count(retrieved_missed_matches) == 10
    end
  end

  describe "list_live_matches_for_driver" do
    test "finds undelivered matches for driver" do
      driver = insert(:driver)
      insert(:completed_match, driver: driver)
      %Match{id: match_id} = insert(:accepted_match, driver: driver)
      assert [%Match{id: ^match_id}] = Drivers.list_live_matches_for_driver(driver)
    end
  end

  describe "list_completed_matches_for_driver" do
    test "finds up to 10 completed matches for driver at desired offset ordered by time of delivery" do
      driver = insert(:driver)
      insert(:accepted_match, driver: driver)

      now = DateTime.utc_now()

      completed_matches =
        for i <- 1..15 do
          %{match: match} =
            insert(:completed_match_state_transition,
              inserted_at: now |> DateTime.add(-i),
              match: build(:match, driver: driver, state: :completed)
            )

          match
        end

      completed_match = completed_matches |> Enum.at(0) |> Repo.preload(:state_transitions)

      {:ok, %{completed_matches: first_page_of_completed_matches}} =
        Drivers.list_completed_matches_for_driver(driver, 0)

      retrieved_completed_match =
        first_page_of_completed_matches |> Enum.at(0) |> Repo.preload(:state_transitions)

      assert (completed_match.state_transitions |> Enum.at(0)).inserted_at ==
               (retrieved_completed_match.state_transitions |> Enum.at(0)).inserted_at

      %Match{id: first_completed_match_id} = completed_matches |> Enum.at(0)
      %Match{id: tenth_completed_match_id} = completed_matches |> Enum.at(9)

      assert %Match{id: ^first_completed_match_id} = first_page_of_completed_matches |> Enum.at(0)
      assert %Match{id: ^tenth_completed_match_id} = first_page_of_completed_matches |> Enum.at(9)
      assert Enum.count(first_page_of_completed_matches) == 10

      {:ok, %{completed_matches: second_page_of_completed_matches}} =
        Drivers.list_completed_matches_for_driver(driver, 1)

      %Match{id: eleventh_completed_match_id} = completed_matches |> Enum.at(10)
      %Match{id: fifthteenth_completed_match_id} = completed_matches |> Enum.at(14)

      assert %Match{id: ^eleventh_completed_match_id} =
               second_page_of_completed_matches |> Enum.at(0)

      assert %Match{id: ^fifthteenth_completed_match_id} =
               second_page_of_completed_matches |> Enum.at(4)

      assert Enum.count(second_page_of_completed_matches) == 5
    end
  end

  describe "vehicles" do
    alias FraytElixir.Drivers.Vehicle

    @valid_attrs %{
      cargo_area_width: 12,
      cargo_area_height: 10,
      cargo_area_length: 4,
      door_width: 12,
      door_height: 12,
      wheel_well_width: 12,
      max_cargo_weight: 12
    }

    @invalid_attrs %{
      cargo_area_width: nil,
      cargo_area_height: nil,
      cargo_area_length: nil,
      door_width: "gibberish",
      door_height: "gibberish",
      wheel_well_width: "gibberish",
      max_cargo_weight: "gibberish"
    }

    test "get_driver_vehicle/1 returns the driver's vehicle with given id" do
      driver = insert(:driver)

      vehicle =
        driver.vehicles
        |> List.first()

      assert %Vehicle{} = fetched_vehicle = Drivers.get_driver_vehicle(driver, vehicle.id)
      assert fetched_vehicle.id == vehicle.id
    end

    test "get_driver_vehicle/1 fails to fetch driver's unassociated vehicle" do
      driver = insert(:driver)
      vehicle = insert(:vehicle)

      refute Drivers.get_driver_vehicle(driver, vehicle.id)
    end

    test "touch_vehicle/1 updates the vehicle" do
      vehicle = insert(:vehicle, updated_at: ~N[2014-10-02 00:29:10])
      assert {:ok, %Vehicle{} = fetched_vehicle} = Drivers.touch_vehicle(vehicle)
      assert :lt == NaiveDateTime.compare(vehicle.updated_at, fetched_vehicle.updated_at)
    end

    test "update_vehicle_cargo_capacity/2 with valid data updates the vehicle" do
      vehicle = insert(:vehicle)

      assert {:ok, %Vehicle{} = vehicle} =
               Drivers.update_vehicle_cargo_capacity(vehicle, @valid_attrs)

      assert vehicle.cargo_area_width == 12
      assert vehicle.cargo_area_height == 10
      assert vehicle.cargo_area_length == 4
      assert vehicle.door_width == 12
      assert vehicle.door_height == 12
      assert vehicle.wheel_well_width == 12
      assert vehicle.max_cargo_weight == 12
    end

    test "update_vehicle_cargo_capacity/2 with invalid data returns error changeset" do
      vehicle = insert(:vehicle)

      assert {:error, %Ecto.Changeset{errors: errors}} =
               Drivers.update_vehicle_cargo_capacity(vehicle, @invalid_attrs)

      assert {_, [validation: :required]} = errors[:cargo_area_width]
      assert {_, [validation: :required]} = errors[:cargo_area_height]
      assert {_, [validation: :required]} = errors[:cargo_area_length]
      assert {_, [type: :integer, validation: :cast]} = errors[:door_width]
      assert {_, [type: :integer, validation: :cast]} = errors[:door_height]
      assert {_, [type: :integer, validation: :cast]} = errors[:wheel_well_width]
      assert {_, [type: :integer, validation: :cast]} = errors[:max_cargo_weight]
    end
  end

  describe "get_driver_email" do
    test "returns user email" do
      driver = insert(:driver)
      assert driver.user.email == Drivers.get_driver_email(driver)
    end

    test "returns user email for driver without preloaded user" do
      driver = insert(:driver)
      fetched_driver = Repo.get!(Driver, driver.id)
      assert driver.user.email == Drivers.get_driver_email(fetched_driver)
    end

    test "returns nil when empty driver is passed" do
      refute Drivers.get_driver_email(%Driver{})
    end

    test "returns nil when nil is passed" do
      refute Drivers.get_driver_email(%Driver{})
    end
  end

  describe "accept_match" do
    test "assigns driver" do
      match = insert(:assigning_driver_match)

      %{id: driver_id, current_location_id: location_id} =
        driver = insert(:driver_with_wallet, current_location: build(:driver_location))

      assert {:ok,
              %Match{
                state: :accepted,
                driver_id: ^driver_id,
                state_transitions: [state_transition | _]
              }} = Drivers.accept_match(match, driver)

      assert %{from: :assigning_driver, to: :accepted, driver_location_id: ^location_id} =
               state_transition
    end

    test "fails when in invalid state" do
      match = insert(:match, state: :pending)
      driver = insert(:driver)

      assert {:error, %Ecto.Changeset{errors: errors}} = Drivers.accept_match(match, driver)

      assert {"is not %{states}",
              [validation: :current_state, states: [:assigning_driver, :scheduled]]} =
               errors[:state]
    end

    test "fails when a car attempts to accept a cargo van match" do
      match = insert(:assigning_driver_match, vehicle_class: Shipment.vehicle_class(:cargo_van))

      driver =
        insert(:driver_with_wallet,
          vehicles: [build(:vehicle, vehicle_class: Shipment.vehicle_class(:car))]
        )

      assert {:error, message} = Drivers.accept_match(match, driver)
      assert String.contains?(message, "vehicle")
    end

    test "fails when a driver account is rejected or disabled" do
      match = insert(:assigning_driver_match)
      disabled_driver = insert(:driver_with_wallet, state: :disabled)
      rejected_driver = insert(:driver_with_wallet, state: :rejected)

      assert {:error, :disabled, "Your account has been disabled"} =
               Drivers.accept_match(match, disabled_driver)

      assert {:error, :disabled, _} = Drivers.accept_match(match, rejected_driver)
    end

    test "fails if driver active_match_limit is nil and driver already has reached the default accepted_match_limit" do
      cur_match_limit = Drivers.get_current_accepted_match_limit()

      driver = insert(:driver_with_wallet, active_match_limit: nil)
      insert_list(cur_match_limit, :accepted_match, driver: driver)
      match = insert(:assigning_driver_match)

      expected_err =
        "You can not have more than #{cur_match_limit} ongoing matches. Please complete your current matches, or contact a Network Operator to be assigned more."

      assert {:error, expected_err} == Drivers.accept_match(match, driver)
    end

    test "fails if driver already has reached its active_match_limit live matches" do
      cur_match_limit = 5

      driver = insert(:driver_with_wallet, active_match_limit: cur_match_limit)
      insert_list(cur_match_limit, :accepted_match, driver: driver)
      match = insert(:assigning_driver_match)

      expected_err =
        "You can not have more than #{cur_match_limit} ongoing matches. Please complete your current matches, or contact a Network Operator to be assigned more."

      assert {:error, expected_err} == Drivers.accept_match(match, driver)
    end

    test "fails if a driver tries to accept a match from a company they have been blocked from" do
      %{id: driver_id} = driver = insert(:driver)
      %{location: %{company: company}} = shipper = insert(:shipper_with_location)
      %{id: company_id} = company

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^driver_id,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "He eats all the beans"
              }} = Drivers.hide_customer_matches(driver, company, "He eats all the beans")

      match = insert(:assigning_driver_match, vehicle_class: 1, shipper: shipper)

      assert {:error, :forbidden} == Drivers.accept_match(match, driver)
    end

    test "Success if a driver tries to accept a match from a company they haven't been blocked from" do
      unrestricted_driver = insert(:driver_with_wallet)
      %{id: blocked_driver_id_1} = blocked_driver_1 = insert(:driver_with_wallet)
      %{id: blocked_driver_id_2} = blocked_driver_2 = insert(:driver_with_wallet)
      %{location: %{company: company}} = shipper = insert(:shipper_with_location)
      %{id: company_id} = company

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^blocked_driver_id_1,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "He eats all the beans"
              }} =
               Drivers.hide_customer_matches(blocked_driver_1, company, "He eats all the beans")

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^blocked_driver_id_2,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "He eats all the beans"
              }} =
               Drivers.hide_customer_matches(blocked_driver_2, company, "He eats all the beans")

      match = insert(:assigning_driver_match, vehicle_class: 1, shipper: shipper)
      assert {:ok, _} = Drivers.accept_match(match, unrestricted_driver)
    end
  end

  describe "assign_match" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    end

    test "sends sms to driver" do
      %Match{id: match_id} =
        match = insert(:assigning_driver_match, driver: nil, slas: [build(:match_sla)])

      %Driver{id: driver_id} = driver = insert(:driver_with_wallet, phone_number: "+12345676543")

      is_reassign = false

      assert {:ok, %Match{driver: %Driver{id: ^driver_id}, state: :accepted}} =
               Drivers.assign_match(match, driver, is_reassign)

      assert sms_notifications =
               Repo.all(
                 from(sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
                 )
               )

      assert Enum.count(sms_notifications) == 1
      assert ["+12345676543"] == sms_notifications |> Enum.map(& &1.phone_number)
    end

    test "should assign driver to inactive match" do
      %{shipper: shipper} = insert(:credit_card)
      match = insert(:inactive_match, driver: nil, shipper: shipper)
      %{id: driver_id} = driver = insert(:driver_with_wallet)

      assert {:ok, match} = Drivers.assign_match(match, driver, false)
      assert %{state: :accepted, driver_id: ^driver_id} = match
    end
  end

  describe "reassign_match" do
    test "A match already assigned is being reassigned and a notification is sent" do
      match = insert(:accepted_match)
      %{driver: old_driver} = match
      new_driver = insert(:driver_with_wallet, phone_number: "+12019999999")
      is_reassign = true

      assert {:ok, %{id: match_id} = match} = Drivers.assign_match(match, new_driver, is_reassign)
      assert match.state == :accepted
      assert old_driver.id != new_driver.id

      assert sms_notifications =
               Repo.all(
                 from(sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
                 )
               )

      assert Enum.count(sms_notifications) == 1
      assert ["+12019999999"] == sms_notifications |> Enum.map(& &1.phone_number)
    end
  end

  describe "toggle_en_route" do
    test "changes match state from accepted to en_route_to_pickup" do
      %{driver: %{current_location_id: location_id}} = match = insert(:match, state: :accepted)

      assert {:ok, %Match{state: :en_route_to_pickup, state_transitions: [state_transition]}} =
               Drivers.toggle_en_route(match)

      assert %{from: :accepted, to: :en_route_to_pickup, driver_location_id: ^location_id} =
               state_transition
    end

    test "changes match state from en_route_to_pickup to accepted" do
      match = insert(:match, state: :en_route_to_pickup)
      assert {:ok, %Match{state: :accepted}} = Drivers.toggle_en_route(match)
    end

    test "sets all other live stops to pending when a given stop is set to en_route" do
      %Match{match_stops: stops} =
        match =
        insert(:en_route_to_dropoff_match, %{
          match_stops:
            build_match_stops_with_items([
              :delivered,
              :signed,
              :pending,
              :en_route,
              :undeliverable
            ])
        })

      stop =
        stops
        |> Enum.find(&(&1.state == :pending))
        |> Map.put(:match, match)

      assert {:ok, %Match{state: :picked_up, match_stops: stops}} = Drivers.toggle_en_route(stop)

      assert %MatchStop{index: 2, state: :en_route} = stops |> Enum.find(&(&1.state == :en_route))
      assert 2 = stops |> Enum.count(&(&1.state == :pending))
      assert 1 = stops |> Enum.count(&(&1.state == :en_route))
      assert 1 = stops |> Enum.count(&(&1.state == :delivered))
      assert 1 = stops |> Enum.count(&(&1.state == :undeliverable))
    end

    test "changes match stop state from en_route to pending" do
      %Match{match_stops: [stop]} = match = insert(:en_route_to_dropoff_match)

      stop = %{stop | match: match}

      assert {:ok, %Match{state: :picked_up, match_stops: [%MatchStop{state: :pending} | []]}} =
               Drivers.toggle_en_route(stop)
    end

    test "gives error tuple when invalid state" do
      match = insert(:match, state: :pending)
      assert {:error, :invalid_state} = Drivers.toggle_en_route(match)
    end

    test "gives error tuple when invalid stop state" do
      stop = insert(:match_stop, state: :delivered, match: insert(:match, state: :picked_up))
      assert {:error, :invalid_state} = Drivers.toggle_en_route(stop)
    end

    test "gives error tuple when invalid match state" do
      stop = insert(:match_stop, state: :pending, match: insert(:match, state: :accepted))
      assert {:error, :invalid_state} = Drivers.toggle_en_route(stop)
    end
  end

  describe "arrive at pickup" do
    test "sets state to arrived_at_pickup" do
      %{driver: %{current_location_id: location_id}} = match = insert(:en_route_to_pickup_match)

      assert {:ok, %Match{state: :arrived_at_pickup, state_transitions: [state_transition]}} =
               Drivers.arrived_at_pickup(match)

      assert %{
               from: :en_route_to_pickup,
               to: :arrived_at_pickup,
               driver_location_id: ^location_id
             } = state_transition
    end

    test "fails when driver is not at the pickup location" do
      match =
        insert(:en_route_to_pickup_match,
          driver:
            insert(:driver,
              current_location: build(:driver_location, geo_location: chicago_point())
            )
        )

      assert {:error, message} = Drivers.arrived_at_pickup(match)

      assert message =~ "is not showing at the current address"
    end

    test "should succeed when parking_spot is set" do
      match = insert(:en_route_to_pickup_match, parking_spot_required: true)

      assert {:ok, %Match{state: :arrived_at_pickup, state_transitions: [stt]}} =
               Drivers.arrived_at_pickup(match, "B512")

      assert %{to: :arrived_at_pickup, notes: "B512"} = stt
    end

    test "should fail when parking_spot is required but it's sent in blank" do
      match = insert(:en_route_to_pickup_match, parking_spot_required: true)

      assert {:ok, _match} = Drivers.arrived_at_pickup(match)
      assert {:ok, _match} = Drivers.arrived_at_pickup(match, "")
    end

    test "should not faild when parking_spot is not set when it is not required" do
      match = insert(:en_route_to_pickup_match, parking_spot_required: false)

      assert {:ok, %Match{state: :arrived_at_pickup, state_transitions: [stt]}} =
               Drivers.arrived_at_pickup(match, "B514")

      assert %{to: :arrived_at_pickup, notes: "B514"} = stt
    end
  end

  describe "picked up" do
    setup do
      match = insert(:arrived_at_pickup_match)
      insert(:match_sla, type: :pickup, match: match, driver_id: match.driver_id)

      %{match: match}
    end

    test "sets state to picked_up with photos", %{match: match} do
      origin_image = %{filename: "origin", binary: FileHelper.binary_image()}
      bill_of_lading_image = %{filename: "bill_of_lading", binary: FileHelper.binary_image()}
      %{driver: %{current_location_id: location_id}} = match

      assert {:ok,
              %Match{
                state: :picked_up,
                id: match_id,
                match_stops: stops,
                state_transitions: [state_transition]
              }} =
               Drivers.picked_up(
                 match,
                 %{
                   origin_photo: origin_image,
                   bill_of_lading_photo: bill_of_lading_image
                 }
               )

      assert %Match{origin_photo: origin_photo, bill_of_lading_photo: bill_of_lading_photo} =
               Shipment.get_match(match_id)

      assert Enum.count(stops, fn %MatchStop{state: state} -> state == :en_route end)

      assert %{
               from: :arrived_at_pickup,
               to: :picked_up,
               driver_location_id: ^location_id
             } = state_transition

      assert origin_photo
      assert bill_of_lading_photo
    end

    test "with one photo", %{match: match} do
      origin_image = %{filename: "origin", binary: FileHelper.binary_image()}

      assert {:ok,
              %Match{
                state: :picked_up,
                id: match_id
              }} =
               Drivers.picked_up(match, %{
                 origin_photo: origin_image
               })

      assert %Match{origin_photo: origin_photo} = Shipment.get_match(match_id)

      assert origin_photo
    end

    test "with no photos", %{match: match} do
      assert {:ok,
              %Match{
                state: :picked_up
              }} = Drivers.picked_up(match, %{})
    end

    test "fails with invalid state" do
      match = insert(:en_route_to_pickup_match)

      assert {:error, :invalid_state} = Drivers.picked_up(match, %{})
    end

    test "fails when barcode reading has not been performed for required items on pickup" do
      match =
        insert(:arrived_at_pickup_match,
          match_stops: [
            build(:match_stop,
              state: :arrived,
              items: [build(:match_stop_item_with_required_barcodes)]
            )
          ]
        )

      origin_image = %{filename: "origin", binary: FileHelper.binary_image()}
      bill_of_lading_image = %{filename: "bill_of_lading", binary: FileHelper.binary_image()}

      result =
        Drivers.picked_up(match, %{
          origin_photo: origin_image,
          bill_of_lading_photo: bill_of_lading_image
        })

      assert {:error, "The barcode of some item has not been scanned."} = result
    end

    test "success when barcode reading has been performed for required items on pickup" do
      %Match{match_stops: [match_stop]} =
        match =
        insert(:arrived_at_pickup_match,
          match_stops: [
            build(:match_stop,
              state: :arrived,
              items: [build(:match_stop_item_with_required_barcodes)]
            )
          ]
        )

      insert(:match_sla, type: :pickup, match: match, driver_id: match.driver_id)
      origin_image = %{filename: "origin", binary: FileHelper.binary_image()}
      bill_of_lading_image = %{filename: "bill_of_lading", binary: FileHelper.binary_image()}

      Enum.each(match_stop.items, fn item ->
        assert {:ok, _bc_reading} =
                 FraytElixir.Shipment.BarcodeReadings.create(item, %{
                   barcode: "123barcode456",
                   type: :pickup,
                   state: :captured
                 })
      end)

      result =
        Drivers.picked_up(match, %{
          origin_photo: origin_image,
          bill_of_lading_photo: bill_of_lading_image
        })

      assert {:ok, %Match{}} = result
    end
  end

  describe "arrive at dropoff" do
    test "sets state to arrived_at_dropoff" do
      %Match{match_stops: [stop]} = match = insert(:en_route_to_dropoff_match)

      stop = %{stop | match: match}

      assert {:ok, %Match{match_stops: [%MatchStop{state: :arrived}], state: :picked_up}} =
               Drivers.arrived_at_stop(stop)
    end

    test "fails when not en route" do
      %Match{match_stops: [stop]} =
        match = insert(:picked_up_match, match_stops: [build(:pending_match_stop)])

      stop = %{stop | match: match}

      assert {:error, :invalid_state} = Drivers.arrived_at_stop(stop)
    end

    test "fails when driver is not at the dropoff location" do
      match =
        %Match{match_stops: [stop]} =
        insert(:en_route_to_dropoff_match,
          driver: insert(:driver, current_location: build(:driver_location))
        )

      stop = %{stop | match: match}

      assert {:error, message} = Drivers.arrived_at_stop(stop)

      assert message =~ "is not showing at the current address"
    end
  end

  describe "deliver_stop" do
    test "sets state to delivered" do
      %Match{match_stops: [stop], driver: %{current_location_id: location_id}} =
        match = insert(:signed_match, match_stops: [build(:signed_match_stop)])

      stop = %{stop | match: match}

      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      assert {:ok,
              %Match{
                state: :completed,
                driver: driver,
                match_stops: [match_stop]
              }, _nps_score_id} = Drivers.deliver_stop(stop)

      %MatchStop{state: :delivered, state_transitions: [state_transition]} =
        match_stop
        |> Repo.preload(:state_transitions)

      assert %{
               from: :signed,
               to: :delivered,
               driver_location_id: ^location_id
             } = state_transition

      :timer.sleep(200)

      driver = Repo.get!(Driver, driver.id) |> Repo.preload(:metrics)

      assert %DriverMetrics{rating: 0.0, rated_matches: 0, completed_matches: 1} = driver.metrics

      assert messages = FakeSlack.get_messages("#test-dispatch")

      Enum.each(messages, fn {_, message} ->
        assert message =~ "has delivered cargo for match stop ##{stop.index + 1}"
      end)
    end

    test "sets state to delivered and save images" do
      %Match{match_stops: [stop]} =
        match = insert(:signed_match, match_stops: [build(:signed_match_stop)])

      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      stop = %{stop | match: match}

      assert {:ok, %Match{state: :completed, match_stops: [%MatchStop{state: :delivered}]},
              _nps_score_id} =
               Drivers.deliver_stop(
                 stop,
                 %{
                   "contents" => "",
                   "filename" => ""
                 }
               )
    end

    test "returns invalid state for match that is already delivered" do
      %Match{match_stops: [stop | _]} = match = insert(:charged_match)
      stop = %{stop | match: match}
      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      assert {:error, :invalid_state, "Match has already been delivered"} =
               Drivers.deliver_stop(stop)
    end

    test "returns invalid state for stop that is not signed" do
      %Match{match_stops: [stop | _]} = match = insert(:en_route_to_dropoff_match)
      stop = %{stop | match: match}

      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      assert {:error, :invalid_state, "Match must be signed before it can be delivered"} =
               Drivers.deliver_stop(stop)
    end
  end

  describe "undeliverable_stop/3" do
    test "sends an danger slack notification to admins for a undeliverable match_stop" do
      %{match_stops: [%{id: stop_id} = stop], driver: %{current_location_id: location_id}} =
        match =
        insert(:signed_match, %{
          match_stops: [build(:en_route_match_stop, index: 0)]
        })

      stop = %{stop | match: match}

      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      assert {:ok,
              %Match{
                match_stops: [stop]
              }} = Drivers.undeliverable_stop(stop, "reason")

      assert %MatchStop{
               id: ^stop_id,
               state: :undeliverable,
               state_transitions: state_transitions
             } = stop |> Repo.preload(:state_transitions)

      state_transition =
        state_transitions
        |> Enum.find(&(&1.to == :undeliverable))

      assert %{
               from: :en_route,
               to: :undeliverable,
               driver_location_id: ^location_id,
               notes: "reason"
             } = state_transition

      assert messages = FakeSlack.get_messages()

      assert Enum.any?(messages, fn {_, message} ->
               message =~ "has marked match stop #1 as undeliverable"
             end)
    end

    test "fails when match is completed" do
      %{match_stops: [stop]} =
        match =
        insert(:completed_match, %{
          match_stops: [build(:en_route_match_stop)]
        })

      stop = %{stop | match: match}

      assert {:error, :invalid_state, "Match" <> _} = Drivers.undeliverable_stop(stop)
    end

    test "fails when already delivered" do
      %{match_stops: [stop]} =
        match =
        insert(:signed_match, %{
          match_stops: [build(:delivered_match_stop)]
        })

      stop = %{stop | match: match}

      assert {:error, :invalid_state, "Stop" <> _} = Drivers.undeliverable_stop(stop)
    end
  end

  describe "reject match" do
    alias FraytElixir.Shipment.HiddenMatch

    test "reject_match/2 adds match to drivers list of rejected matches" do
      %Match{id: match_id} = match = insert(:assigning_driver_match)
      %Driver{id: driver_id} = driver = insert(:driver_with_wallet)

      assert {:ok,
              %HiddenMatch{
                match_id: ^match_id,
                driver_id: ^driver_id,
                reason: nil,
                type: "driver_rejected"
              }} = Drivers.reject_match(match, driver)
    end
  end

  describe "update_driver_metrics" do
    test "updates driver metrics" do
      d =
        %{id: driver_id, metrics: %{id: metrics_id}} =
        insert(:driver, metrics: insert(:driver_metrics, inserted_at: ~N[2020-01-01 00:00:00]))

      insert_list(5, :completed_match, driver: d, driver_total_pay: 1000)
      insert_list(10, :charged_match, driver: d, driver_total_pay: 1000)
      insert_list(3, :charged_match, rating: 4, driver: d, driver_total_pay: 1000)
      insert_list(3, :hidden_match, type: "driver_cancellation", driver: d)
      insert(:charged_match, rating: 1, driver: d, driver_total_pay: 1000)

      assert {:ok,
              %DriverMetrics{
                id: ^metrics_id,
                inserted_at: ~N[2020-01-01 00:00:00],
                total_earned: 190_00,
                canceled_matches: 3,
                completed_matches: 19,
                rated_matches: 4,
                rating: 3.25,
                activity_rating: 0.0,
                fulfillment_rating: 4.45,
                sla_rating: 0.0,
                internal_rating: 3.76,
                driver_id: ^driver_id
              }} = Drivers.update_driver_metrics(d)
    end

    test "updates when no existing metrics" do
      d = %{id: driver_id} = insert(:driver, metrics: nil)
      insert_list(5, :completed_match, driver: d, driver_total_pay: 1000)
      insert_list(10, :charged_match, driver: d, driver_total_pay: 1000)
      insert_list(3, :charged_match, rating: 4, driver: d, driver_total_pay: 1000)
      insert_list(3, :hidden_match, type: "driver_cancellation", driver: d)
      insert(:charged_match, rating: 1, driver: d, driver_total_pay: 1000)

      assert {:ok,
              %DriverMetrics{
                total_earned: 190_00,
                canceled_matches: 3,
                completed_matches: 19,
                rated_matches: 4,
                rating: 3.25,
                activity_rating: 0.0,
                fulfillment_rating: 4.45,
                sla_rating: 0.0,
                internal_rating: 3.76,
                driver_id: ^driver_id
              }} = Drivers.update_driver_metrics(d)
    end

    test "sets all to 0 when no matches" do
      d = %{id: driver_id} = insert(:driver, metrics: nil)

      assert {:ok,
              %DriverMetrics{
                total_earned: 0,
                canceled_matches: 0,
                completed_matches: 0,
                rated_matches: 0,
                rating: 0.0,
                activity_rating: 0.0,
                fulfillment_rating: 0.0,
                sla_rating: 0.0,
                internal_rating: 0.0,
                driver_id: ^driver_id
              }} = Drivers.update_driver_metrics(d)
    end

    test "calculates activity rating" do
      two_months_ago =
        DateTime.utc_now()
        |> DateTime.add(-60 * 24 * 60 * 60)

      ten_days_ago = DateTime.utc_now() |> DateTime.add(-10 * 24 * 60 * 60)

      driver = insert(:driver)

      insert(:completed_match_state_transition,
        inserted_at: ten_days_ago,
        match: build(:match, driver: driver, state: :completed)
      )

      insert(:completed_match_state_transition,
        inserted_at: two_months_ago,
        match: build(:match, driver: driver, state: :completed)
      )

      assert {:ok, %{activity_rating: 4.0}} = Drivers.update_driver_metrics(driver)
    end

    test "activity rating is 1.0 if not active for three months" do
      three_months_ago =
        DateTime.utc_now()
        |> DateTime.add(-90 * 24 * 60 * 60)

      driver = insert(:driver)

      insert(:completed_match_state_transition,
        inserted_at: three_months_ago,
        match: build(:match, driver: driver, state: :completed)
      )

      assert {:ok, %{activity_rating: 1.0}} = Drivers.update_driver_metrics(driver)
    end

    test "activity rating is 5.0 if active today" do
      driver = insert(:driver)

      insert(:completed_match_state_transition,
        match: build(:match, driver: driver, state: :completed)
      )

      assert {:ok, %{activity_rating: 5.0}} = Drivers.update_driver_metrics(driver)
    end

    test "properly calculates sla rating" do
      driver = insert(:driver)

      on_time_match = insert(:completed_match, driver: driver)
      match_state_transition_through_to(:delivered, on_time_match)

      insert(:match_sla,
        match: on_time_match,
        driver: driver,
        completed_at: DateTime.utc_now(),
        inserted_at: DateTime.utc_now(),
        type: :delivery
      )

      on_time_match2 = insert(:completed_match, driver: driver)
      match_state_transition_through_to(:delivered, on_time_match2)

      insert(:match_sla,
        match: on_time_match2,
        driver: driver,
        completed_at: DateTime.utc_now(),
        inserted_at: DateTime.utc_now(),
        type: :delivery
      )

      half_hour_too_late = DateTime.utc_now() |> DateTime.add(12 * 60 * 60)

      late_match = insert(:completed_match, driver: driver)

      insert(:accepted_match_state_transition, match: late_match)

      insert(:completed_match_state_transition, match: late_match, inserted_at: half_hour_too_late)

      insert(:match_sla,
        match: late_match,
        driver: driver,
        completed_at: half_hour_too_late,
        inserted_at: DateTime.utc_now(),
        type: :delivery
      )

      assert {:ok, %{sla_rating: 3.6666666666666665}} = Drivers.update_driver_metrics(driver)
    end

    test "sla rating is 5.0 for delivering scheduled match on time" do
      driver = insert(:driver)
      half_hour_ago = DateTime.utc_now() |> DateTime.add(-30 * 60)
      half_a_day_ago = DateTime.utc_now() |> DateTime.add(-12 * 60 * 60)

      on_time_match =
        insert(:completed_match,
          driver: driver,
          scheduled: true,
          pickup_at: half_hour_ago,
          inserted_at: half_a_day_ago
        )

      insert(:accepted_match_state_transition, match: on_time_match, inserted_at: half_a_day_ago)

      insert(:completed_match_state_transition,
        match: on_time_match,
        inserted_at: DateTime.utc_now()
      )

      insert(:match_sla,
        match: on_time_match,
        driver: driver,
        completed_at: DateTime.utc_now(),
        inserted_at: DateTime.utc_now(),
        type: :delivery
      )

      assert {:ok, %{sla_rating: 5.0}} = Drivers.update_driver_metrics(driver)
    end

    test "sla rating is 1.0 for delivering scheduled match over 90 mins after pickup_at" do
      driver = insert(:driver)
      two_hours_ago = DateTime.utc_now() |> DateTime.add(-2 * 60 * 60)
      half_a_day_ago = DateTime.utc_now() |> DateTime.add(-12 * 60 * 60)

      late_match =
        insert(:completed_match,
          driver: driver,
          scheduled: true,
          pickup_at: two_hours_ago,
          inserted_at: half_a_day_ago
        )

      insert(:accepted_match_state_transition, match: late_match, inserted_at: half_a_day_ago)

      insert(:completed_match_state_transition,
        match: late_match,
        inserted_at: DateTime.utc_now()
      )

      assert {:ok, %{sla_rating: 0.0}} = Drivers.update_driver_metrics(driver)
    end

    test "update_all_driver_metrics" do
      insert_list(5, :driver, metrics: nil)
      insert_list(3, :driver, metrics: insert(:driver_metrics))

      assert {:ok, 8, nil} = Drivers.update_all_driver_metrics()

      assert from(dm in DriverMetrics) |> Repo.all() |> Enum.count() == 8
    end

    test "update_all_driver_metrics only counts driver" do
      d1 = %{id: d1_id} = insert(:driver, metrics: nil)
      insert_list(5, :completed_match, driver: d1, driver_total_pay: 1000)
      insert_list(10, :charged_match, driver: d1, driver_total_pay: 1000)
      insert_list(3, :charged_match, rating: 4, driver: d1, driver_total_pay: 1000)

      insert_list(3, :hidden_match,
        type: "driver_cancellation",
        driver: d1,
        match: insert(:match, driver: nil)
      )

      insert(:charged_match, rating: 1, driver: d1, driver_total_pay: 10_00)

      d2 = %{id: d2_id} = insert(:driver, metrics: nil)
      insert_list(5, :completed_match, driver: d2, driver_total_pay: 100_00)
      insert_list(8, :charged_match, driver: d2, driver_total_pay: 100_00)
      insert_list(4, :charged_match, rating: 5, driver: d2, driver_total_pay: 100_00)

      insert_list(2, :hidden_match,
        type: "driver_cancellation",
        driver: d2,
        match: insert(:match, driver: nil)
      )

      insert(:charged_match, rating: 1, driver: d2, driver_total_pay: 100_00)

      assert {:ok, 2, nil} = Drivers.update_all_driver_metrics()

      assert [
               %DriverMetrics{
                 total_earned: 190_00,
                 canceled_matches: 3,
                 completed_matches: 19,
                 rated_matches: 4,
                 rating: 3.25,
                 activity_rating: 0.0,
                 fulfillment_rating: 4.45,
                 sla_rating: 0.0,
                 internal_rating: 3.76,
                 driver_id: ^d1_id
               },
               %DriverMetrics{
                 total_earned: 1_800_00,
                 canceled_matches: 2,
                 completed_matches: 18,
                 rated_matches: 5,
                 rating: 4.2,
                 activity_rating: 0.0,
                 fulfillment_rating: 4.6,
                 sla_rating: 0.0,
                 internal_rating: 4.37,
                 driver_id: ^d2_id
               }
             ] = from(dm in DriverMetrics) |> Repo.all() |> Enum.sort_by(& &1.total_earned)
    end

    test "ignores unapproved drivers" do
      insert(:driver, metrics: nil, state: :rejected)
      insert(:driver, metrics: nil, state: :disabled)

      assert {:ok, 0, nil} = Drivers.update_all_driver_metrics()

      insert(:driver, metrics: nil, state: :approved)
      insert(:driver, metrics: nil, state: :registered)
      assert {:ok, 2, nil} = Drivers.update_all_driver_metrics()
    end

    test "update_all_driver_metrics!" do
      insert_list(5, :driver, metrics: nil)
      insert_list(3, :driver, metrics: fn -> build(:driver_metrics) end)

      assert {8, nil} = Drivers.update_all_driver_metrics!()

      assert from(dm in DriverMetrics) |> Repo.all() |> Enum.count() == 8
    end
  end

  describe "cancel_match" do
    test "sets driver to nil" do
      match = insert(:accepted_match)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      assert {:ok, %Match{driver_id: nil}} = Drivers.cancel_match(match, "my reason")
    end

    test "sets state to assigning_driver" do
      %{driver: %{current_location_id: location_id}} = match = insert(:accepted_match)
      insert(:match_sla, match: match, driver_id: match.driver_id, type: :pickup)
      insert(:match_sla, match: match, driver_id: match.driver_id, type: :delivery)

      assert {:ok,
              %Match{
                state: :assigning_driver,
                state_transitions: [canceled_state_transition, assigning_state_transition]
              }} = Drivers.cancel_match(match, "my reason")

      assert %{
               from: :accepted,
               to: :driver_canceled,
               driver_location_id: ^location_id
             } = canceled_state_transition

      assert %{
               from: :driver_canceled,
               to: :assigning_driver
             } = assigning_state_transition
    end

    test "saves cancellation reason" do
      %Match{driver: driver} = match = insert(:accepted_match)

      insert(:match_sla, match: match, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :pickup, driver_id: match.driver_id)
      insert(:match_sla, match: match, type: :delivery, driver_id: match.driver_id)

      Drivers.cancel_match(match, "my reason")
      %Driver{hidden_matches: hidden} = Repo.preload(driver, [:hidden_matches])
      assert %{reason: "my reason"} = hidden |> hd
    end

    test "does not save cancellation reason and rolls back if invalid state" do
      match = insert(:completed_match)
      assert {:error, :invalid_state} = Drivers.cancel_match(match, "my reason")
      assert Repo.all(HiddenMatch) |> Enum.count() == 0
    end
  end

  describe "unable_to_pickup_match" do
    test "sends an danger slack notification to admins when a driver marked a match as unable to pickup" do
      match = insert(:match, state: :arrived_at_pickup)
      location = insert(:driver_location)

      assert {:ok, _match} = Drivers.unable_to_pickup_match(match, "reason", location)
      assert messages = FakeSlack.get_messages()

      assert Enum.any?(messages, fn {_, message} ->
               message =~ "has marked a match as unable to pickup"
             end)
    end

    test "fails for match status before or after the driver arrived at the pickup" do
      match = insert(:match, state: :arrived_at_pickup)
      location = insert(:driver_location)

      assert {:ok, _match} = Drivers.unable_to_pickup_match(match, "reason", location)

      match = insert(:accepted_match)
      {:error, :invalid_state} = Drivers.unable_to_pickup_match(match, "reason", location)

      match = insert(:match, state: :picked_up)
      {:error, :invalid_state} = Drivers.unable_to_pickup_match(match, "reason", location)
    end
  end

  describe "sign_stop" do
    test "sets state to signed with photos and a signature name" do
      signature_image = %{
        "filename" => "signature_photo",
        "contents" => FileHelper.base64_image()
      }

      %{driver: %{current_location_id: location_id}} = match = insert(:arrived_at_dropoff_match)
      [stop | _] = match.match_stops

      stop = %{stop | match: match}

      assert {:ok,
              %Match{
                state: :picked_up,
                match_stops: [
                  stop
                  | _
                ]
              }} = Drivers.sign_stop(stop, signature_image, "Hellen Job")

      %MatchStop{
        signature_name: "Hellen Job",
        signature_photo: %{file_name: "signature_photo"},
        state_transitions: [state_transition]
      } = stop |> Repo.preload(:state_transitions)

      assert %{
               from: :arrived,
               to: :signed,
               driver_location_id: ^location_id
             } = state_transition
    end

    test "fails when barcode reading has not been performed for required items on delivery" do
      signature_image = %{
        "filename" => "signature_photo",
        "contents" => FileHelper.base64_image()
      }

      receiver_name = "Jhon Doe"

      %Match{match_stops: [stop]} =
        match =
        insert(
          :signed_match,
          match_stops: [
            build(:match_stop,
              state: :arrived,
              items: [build(:match_stop_item_with_required_barcodes)]
            )
          ]
        )

      stop = %{stop | match: match}

      assert {:error, "The barcode of some item has not been scanned."} =
               Drivers.sign_stop(stop, signature_image, receiver_name)
    end

    test "success when barcode reading has been performed for required items on delivery" do
      signature_image = %{
        "filename" => "signature_photo",
        "contents" => FileHelper.base64_image()
      }

      receiver_name = "Jhon Doe"

      %Match{match_stops: [stop]} =
        match =
        insert(
          :signed_match,
          match_stops: [
            build(:match_stop,
              state: :arrived,
              items: [build(:match_stop_item_with_required_barcodes)]
            )
          ]
        )

      Enum.each(stop.items, fn item ->
        assert {:ok, _bc_reading} =
                 FraytElixir.Shipment.BarcodeReadings.create(item, %{
                   barcode: "123barcode456",
                   type: :delivery,
                   state: :captured
                 })
      end)

      stop = %{stop | match: match}

      assert {:ok, %Match{match_stops: [stop]}} =
               Drivers.sign_stop(
                 stop,
                 signature_image,
                 receiver_name
               )

      assert stop.state == :signed
    end
  end

  describe "get_current_location" do
    test "get_current_location finds driver location by driver id" do
      %Driver{current_location_id: driver_location_id, id: driver_id} =
        insert(:driver, current_location: build(:driver_location))

      assert %DriverLocation{id: ^driver_location_id} = Drivers.get_current_location(driver_id)
    end

    test "get_current_location finds driver location by driver" do
      %Driver{current_location_id: driver_location_id} =
        driver = insert(:driver, current_location: build(:driver_location))

      assert %DriverLocation{id: ^driver_location_id} = Drivers.get_current_location(driver)
    end

    test "driver with no location returns error" do
      %Driver{id: driver_id} = insert(:driver)
      refute Drivers.get_current_location(driver_id)
    end
  end

  describe "get_driver_metrics/1" do
    test "returns metrics for driver" do
      %{id: driver_id} =
        driver = insert(:driver, metrics: build(:driver_metrics, completed_matches: 3))

      assert %DriverMetrics{
               driver_id: ^driver_id,
               rating: 0.0,
               completed_matches: 3,
               rated_matches: 0
             } = Drivers.get_driver_metrics(driver)
    end

    test "returns nil for driver with no existing metrics" do
      driver = insert(:driver, metrics: nil)

      refute Drivers.get_driver_metrics(driver)
    end

    test "returns nil when nil is passed" do
      refute Drivers.get_driver_metrics(nil)
    end
  end

  describe "disable and reactivate driver accounts" do
    test "disable an account with a note" do
      driver = insert(:driver)
      notes = "This is a note"

      email =
        Email.disable_driver_account_email(%{
          email: driver.user.email,
          first_name: driver.first_name,
          last_name: driver.last_name,
          note: notes
        })

      assert {:ok, driver} = Drivers.disable_driver_account(driver, notes)
      state_transition = List.first(driver.state_transitions)

      assert driver.state == :disabled
      assert state_transition.notes == notes
      assert_delivered_email(email)
    end

    test "disable an account without a note" do
      driver = insert(:driver)
      notes = ""

      email =
        Email.disable_driver_account_email(%{
          email: driver.user.email,
          first_name: driver.first_name,
          last_name: driver.last_name,
          note: notes
        })

      assert {:ok, driver} = Drivers.disable_driver_account(driver, notes)
      state_transition = List.first(driver.state_transitions)

      assert driver.state == :disabled
      assert state_transition.notes == notes
      assert_delivered_email(email)
    end

    test "disable an account with a nil note" do
      driver = insert(:driver)
      notes = nil

      email =
        Email.disable_driver_account_email(%{
          email: driver.user.email,
          first_name: driver.first_name,
          last_name: driver.last_name,
          note: notes
        })

      assert {:ok, driver} = Drivers.disable_driver_account(driver, notes)
      state_transition = List.first(driver.state_transitions)

      assert driver.state == :disabled
      assert state_transition.notes == notes
      assert_delivered_email(email)
    end

    test "reactivate an account" do
      driver = insert(:driver, state: :disabled)

      email =
        Email.reactivate_driver_account_email(%{
          email: driver.user.email,
          first_name: driver.first_name,
          last_name: driver.last_name
        })

      assert {:ok, driver} = Drivers.reactivate_driver(driver)
      assert driver.state == :approved
      assert_delivered_email(email)
    end
  end

  describe "validate_match_assignment" do
    test "with a single match assigned to driver" do
      %Driver{id: driver_id} = driver = insert(:driver)
      %Match{id: match_id} = insert(:match, driver: driver)

      assert {:ok, ^match_id} =
               Drivers.validate_match_assignment(driver_id, String.slice(match_id, 0..7))
    end

    test "with a match not assigned to driver" do
      driver = insert(:driver)
      %Match{id: match_id} = insert(:match, driver: driver)
      %Driver{id: other_driver_id} = insert(:driver)

      assert {:error, "match not found"} =
               Drivers.validate_match_assignment(other_driver_id, String.slice(match_id, 0..7))
    end

    test "with multiple matches found" do
      %Driver{id: driver_id} = driver = insert(:driver)
      insert(:match, id: "272ef0d5-0c5a-4427-ae36-233bb9e4c479", driver: driver)
      insert(:match, id: "272ef0d5-0c5a-4427-ae36-233bb9e4c470", driver: driver)

      assert {:error, message, matches} = Drivers.validate_match_assignment(driver_id, "272ef0d5")
      assert String.contains?(message, "multiple")
      assert Enum.count(matches) == 2
    end
  end

  describe "driver penalties" do
    test "add penalties" do
      driver = insert(:driver)

      assert {:ok, %Driver{penalties: number}} = Drivers.update_driver(driver, %{penalties: 4})
      assert number == 4
    end

    test "remove penalties" do
      driver = insert(:driver, penalties: 5)

      assert {:ok, %Driver{penalties: number}} = Drivers.update_driver(driver, %{penalties: 2})
      assert number == 2
    end

    test "remove all penalties" do
      driver = insert(:driver, penalties: 5)

      assert {:ok, %Driver{penalties: number}} = Drivers.update_driver(driver, %{penalties: 0})
      assert number == 0
    end
  end

  describe "update_current_location" do
    test "updates current location and adds to driver_locations" do
      %Driver{id: driver_id} = driver = insert(:driver)

      assert {:ok, %Driver{id: ^driver_id, current_location_id: current_location_id}} =
               Drivers.update_current_location(driver, chris_house_point())

      assert %Driver{
               current_location_id: ^current_location_id,
               driver_locations: driver_locations
             } = Drivers.get_driver!(driver_id) |> Repo.preload(:driver_locations)

      assert driver_locations |> Enum.map(& &1.id) == [current_location_id]
    end

    test "updates current location and adds multiple locations to driver_locations" do
      %Driver{id: driver_id} = driver = insert(:driver)

      assert {:ok, %Driver{id: ^driver_id}} =
               Drivers.update_current_location(driver, chris_house_point())

      assert {:ok, %Driver{id: ^driver_id, current_location_id: current_location_id}} =
               Drivers.update_current_location(driver, gaslight_point())

      assert %Driver{
               current_location_id: ^current_location_id,
               driver_locations: driver_locations
             } = Drivers.get_driver!(driver_id) |> Repo.preload(:driver_locations)

      assert driver_locations |> Enum.count() == 2
    end
  end

  describe "get_max_volume" do
    test "returns 45 when vehicle class 2 is the only vehicle a driver has" do
      assert insert(:driver)
             |> Drivers.get_max_volume() == 45
    end

    test "returns 150 when three is the highest class available" do
      assert insert(:driver, %{
               vehicles: [build(:cargo_van), build(:midsize)]
             })
             |> Drivers.get_max_volume() == 150
    end
  end

  describe "get_max_vehicle_class" do
    test "returns 2 when vehicle class 2 is the only vehicle a driver has" do
      assert insert(:driver)
             |> Drivers.get_max_vehicle_class() == 2
    end

    test "returns 3 when three is the highest class available" do
      assert insert(:driver, %{
               vehicles: [build(:cargo_van), build(:midsize)]
             })
             |> Drivers.get_max_vehicle_class() == 3
    end
  end

  describe "get_poorly_rated_matches" do
    test "returns only matches rated less than 5 stars" do
      %{id: id} = driver = insert(:driver_with_wallet)

      [%{id: poor_match_id, rating: 1} | _] =
        insert_list(5, :completed_match,
          driver: driver,
          rating: 1,
          rating_reason: "Could not track driver"
        )

      [%{id: five_star_match_id, rating: 5} | _] =
        insert_list(10, :completed_match, driver: driver, rating: 5)

      poorly_rated_matches = Drivers.get_poorly_rated_matches(id)

      assert poorly_rated_matches
             |> Enum.any?(fn %{match_id: match_id, rating: rating} ->
               match_id == poor_match_id and rating == 1
             end)

      assert poorly_rated_matches
             |> Enum.all?(fn %{match_id: match_id, rating: rating} ->
               match_id != five_star_match_id and rating != 5
             end)
    end
  end

  describe "hide_customer_matches/3" do
    test "creates hidden customer for company" do
      %{id: driver_id} = driver = insert(:driver)
      %{id: company_id} = company = insert(:company)

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^driver_id,
                company_id: ^company_id,
                shipper_id: nil,
                reason: "He eats all the beans"
              }} = Drivers.hide_customer_matches(driver, company, "He eats all the beans")
    end

    test "creates hidden customer for shipper" do
      %{id: driver_id} = driver = insert(:driver)
      %{id: shipper_id} = shipper = insert(:shipper)

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^driver_id,
                shipper_id: ^shipper_id,
                company_id: nil,
                reason: "He eats all the beans"
              }} = Drivers.hide_customer_matches(driver, shipper, "He eats all the beans")
    end
  end

  describe "delete_hidden_customer/1" do
    test "delete hidden customer for company" do
      %{id: driver_id} = driver = insert(:driver)
      %{id: company_id} = company = insert(:company)
      hidden_customer = insert(:hidden_customer, driver: driver, company: company)

      assert {:ok,
              %HiddenCustomer{
                driver_id: ^driver_id,
                company_id: ^company_id
              }} = Drivers.delete_hidden_customer(hidden_customer.id)

      refute Repo.get(HiddenCustomer, hidden_customer.id)
    end

    test "fails when no match" do
      shipper = insert(:shipper)
      insert(:hidden_customer, shipper: shipper)

      assert {:error, :not_found} = Drivers.delete_hidden_customer(shipper.id)
    end
  end

  describe "update_driver_wallet" do
    test "updates driver wallet state" do
      driver = insert(:driver, wallet_state: nil)

      assert {:ok, %Driver{wallet_state: :UNCLAIMED}} =
               Drivers.update_driver_wallet(driver, "UNCLAIMED")
    end

    test "fails with invalid state" do
      driver = insert(:driver, wallet_state: nil)

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  wallet_state: {_, [type: FraytElixir.Drivers.WalletEnum, validation: :cast]}
                ]
              }} = Drivers.update_driver_wallet(driver, "BAD_STATE")
    end
  end

  describe "get_locations_for_match/1" do
    test "list driver locations for a match" do
      match =
        insert(:completed_match,
          driver: build(:driver_with_wallet, first_name: "New", last_name: "Driver")
        )

      match_state_transition_through_to(:completed, match)

      insert(:driver_location,
        geo_location: %Geo.Point{
          coordinates: {-84.61019579999999, 40.283527},
          properties: %{},
          srid: nil
        },
        driver: match.driver,
        inserted_at: DateTime.add(DateTime.utc_now(), 120, :second)
      )

      assert match
             |> Drivers.get_locations_for_match()
             |> Enum.count() == 1
    end

    test "should be empty when not en route" do
      match = insert(:accepted_match)

      driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      insert(:driver_location,
        geo_location: %Geo.Point{
          coordinates: {-84.61019579999999, 40.283527},
          properties: %{},
          srid: nil
        },
        driver: driver
      )

      match_state_transition_through_to(:accepted, match)

      assert match
             |> Drivers.get_locations_for_match()
             |> Enum.count() == 0
    end

    test "should be empty for a match if the state of the match is not accepted" do
      match = insert(:assigning_driver_match)

      driver =
        insert(:driver_with_wallet,
          phone_number: "+12345676543",
          current_location: build(:driver_location)
        )

      insert(:driver_location,
        geo_location: %Geo.Point{
          coordinates: {-84.61019579999999, 40.283527},
          properties: %{},
          srid: nil
        },
        driver: driver
      )

      match_state_transition_through_to(:assigning_driver, match)

      assert match
             |> Drivers.get_locations_for_match()
             |> Enum.count() == 0
    end
  end
end
