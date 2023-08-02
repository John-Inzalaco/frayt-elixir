defmodule FraytElixirWeb.Admin.CapacityTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  alias FraytElixirWeb.DisplayFunctions

  setup [:create_and_login_admin]

  feature "displays list of drivers", %{session: session} do
    drivers = insert_list(3, :driver)
    Enum.each(drivers, &insert(:driver_location, driver: &1))

    session
    |> Admin.visit_page("markets/capacity")
    |> assert_has(css(".driver__vehicle-details", count: 3))
    |> Admin.assert_has_text(css(".driver__number", count: 3, at: 0), "1")
    |> Admin.assert_has_text(css(".driver__number", count: 3, at: 1), "2")
    |> Admin.assert_has_text(css(".driver__number", count: 3, at: 2), "3")
  end

  feature "displays driver details", %{session: session} do
    insert(:driver,
      first_name: "Test",
      last_name: "Driver",
      phone_number: "+14324569876",
      updated_at: ~N[2000-01-01 23:00:07],
      vehicles: [
        build(:vehicle, vehicle_class: 1, year: 2012, make: "Somemake", model: "Somemodel"),
        build(:vehicle, vehicle_class: 3, year: "2020", make: "Subaru", model: "Some Model")
      ],
      current_location: build(:driver_location, driver: nil)
    )

    session
    |> Admin.visit_page("markets/capacity")
    |> assert_has(css(".driver__vehicle-details .driver-info-container h3", text: "Test Driver"))
    |> assert_has(css(".driver__vehicle-details p", text: "+1 432-456-9876"))
    |> assert_has(css(".driver__vehicle-details p", text: "01/01/2000"))
    |> assert_has(css("[data-test-id='driver-vehicle']", text: "Car (2012 Somemake Somemodel)"))
    |> assert_has(
      css("[data-test-id='driver-vehicle']", text: "Cargo Van (2020 Subaru Some Model)")
    )
  end

  feature "toggle address type", %{session: session} do
    driver =
      insert(:driver,
        address:
          build(:address, address: "123 Some Place", city: "Cincinnati", state: "OH", zip: "45202")
      )

    insert(:driver_location, driver: driver)

    session
    |> Admin.visit_page("markets/capacity")
    |> refute_has(
      css(".driver__vehicle-details [data-test-id='driver-address']",
        text: "123 Some Place, Cincinnati, OH 45202"
      )
    )
    |> set_value(css("option[value='address']"), :selected)
    |> click(button("Search"))
    |> assert_has(
      css(".driver__vehicle-details [data-test-id='driver-address']",
        text: "123 Some Place, Cincinnati, OH 45202"
      )
    )
    |> set_value(css("option[value='current_location']"), :selected)
    |> click(button("Search"))
    |> refute_has(
      css(".driver__vehicle-details [data-test-id='driver-address']",
        text: "123 Some Place, Cincinnati, OH 45202"
      )
    )
  end

  feature "drivers are paginated", %{session: session} do
    drivers = insert_list(25, :driver, first_name: "Driver", last_name: "One")
    Enum.each(drivers, &insert(:driver_location, driver: &1))

    session
    |> Admin.visit_page("markets/capacity")
    |> assert_has(
      css(".driver__vehicle-details .driver-info-container", text: "Driver One", count: 20)
    )
    |> Admin.assert_has_text(css(".driver__number", count: 20, at: 0), "1")
    |> Admin.next_page()
    |> assert_has(
      css(".driver__vehicle-details .driver-info-container", text: "Driver One", count: 5)
    )
    |> Admin.assert_has_text(css(".driver__number", count: 5, at: 0), "21")
    |> Admin.previous_page()
    |> assert_has(
      css(".driver__vehicle-details .driver-info-container", text: "Driver One", count: 20)
    )
    |> Admin.assert_has_text(css(".driver__number", count: 20, at: 0), "1")
  end

  @tag :skip
  feature "search filters by vehicle type", %{session: session} do
    insert(:driver,
      first_name: "Driver",
      last_name: "One",
      vehicles: [build(:vehicle, vehicle_class: 1)]
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Two",
      vehicles: [build(:vehicle, vehicle_class: 2), build(:vehicle, vehicle_class: 1)]
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Three",
      vehicles: [build(:vehicle, vehicle_class: 3)]
    )

    session
    |> Admin.visit_page("markets/capacity")
    |> assert_has(css(".driver__vehicle-details", count: 3))
    |> assert_has(css(".driver__vehicle-details", count: 3))
    |> click(css("label[for='search_vehicle_type_1']"))
    |> assert_has(css(".driver__vehicle-details", count: 2))
    |> refute_has(css(".driver__vehicle-details", text: "Driver One"))
    |> click(css("#search_vehicle_type_2"))
    |> assert_has(css(".driver__vehicle-details", count: 1))
    |> assert_has(css(".driver__vehicle-details", text: "Driver Three"))
    |> click(css("#search_vehicle_type_3"))
    |> refute_has(css(".driver__vehicle-details"))
    |> click(css("#search_vehicle_type_2"))
    |> assert_has(css(".driver__vehicle-details", text: "Driver Two"))
    |> assert_has(css(".driver__vehicle-details", count: 1))
  end

  feature "search filters and orders by last seen proximity to pickup address", %{
    session: session
  } do
    chris_house_driver =
      insert(:driver,
        current_location: build(:driver_location, driver: nil, geo_location: chris_house_point())
      )

    findlay_market_driver =
      insert(:driver,
        current_location:
          build(:driver_location, driver: nil, geo_location: findlay_market_point())
      )

    chicago_driver =
      insert(:driver,
        current_location: build(:driver_location, driver: nil, geo_location: chicago_point())
      )

    gaslight_driver =
      insert(:driver,
        current_location: build(:driver_location, driver: nil, geo_location: gaslight_point())
      )

    session
    |> Admin.visit_page("markets/capacity")
    |> assert_has(css(".driver__vehicle-details", count: 4))
    |> fill_in(text_field("dt_filter_capacity_pickup_address"),
      with: "520 Vine St., Cincinnati, OH"
    )
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: 300)
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 4))
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 4, at: 0),
      DisplayFunctions.display_phone(gaslight_driver.phone_number)
    )
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 4, at: 1),
      DisplayFunctions.display_phone(findlay_market_driver.phone_number)
    )
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 4, at: 2),
      DisplayFunctions.display_phone(chris_house_driver.phone_number)
    )
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 4, at: 3),
      DisplayFunctions.display_phone(chicago_driver.phone_number)
    )
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: "50")
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 3))
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 3, at: 0),
      DisplayFunctions.display_phone(gaslight_driver.phone_number)
    )
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 3, at: 1),
      DisplayFunctions.display_phone(findlay_market_driver.phone_number)
    )
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 3, at: 2),
      DisplayFunctions.display_phone(chris_house_driver.phone_number)
    )
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: "10")
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 2))
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 2, at: 0),
      DisplayFunctions.display_phone(gaslight_driver.phone_number)
    )
    |> Admin.assert_has_text(
      css(".driver__vehicle-details", count: 2, at: 1),
      DisplayFunctions.display_phone(findlay_market_driver.phone_number)
    )
  end

  feature "search filters and orders by home proximity to pickup address", %{session: session} do
    insert(:driver,
      first_name: "Driver",
      last_name: "One",
      address: build(:address, geo_location: chris_house_point()),
      current_location: nil
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Two",
      address: build(:address, geo_location: findlay_market_point()),
      current_location: nil
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Three",
      address: build(:address, geo_location: chicago_point()),
      current_location: nil
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Four",
      address: build(:address, geo_location: gaslight_point()),
      current_location: nil
    )

    session
    |> Admin.visit_page("markets/capacity")
    |> set_value(css("option[value='address']"), :selected)
    |> fill_in(text_field("dt_filter_capacity_pickup_address"),
      with: "520 Vine St., Cincinnati, OH"
    )
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: 300)
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 4))
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 4, at: 0), "Driver Four")
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 4, at: 1), "Driver Two")
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 4, at: 2), "Driver One")
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 4, at: 3), "Driver Three")
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: "50")
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 3))
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 3, at: 0), "Driver Four")
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 3, at: 1), "Driver Two")
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 3, at: 2), "Driver One")
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: "10")
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 2))
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 2, at: 0), "Driver Four")
    |> Admin.assert_has_text(css(".driver__vehicle-details", count: 2, at: 1), "Driver Two")
  end

  feature "search works if some drivers don't have an address", %{session: session} do
    insert(:driver, address: nil, first_name: "No", last_name: "Address")
    insert(:driver, first_name: "Has", last_name: "Address")

    session
    |> Admin.visit_page("markets/capacity")
    |> set_value(css("option[value='address']"), :selected)
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 2))
    |> assert_has(css(".driver__vehicle-details .driver-info-container", text: "Has Address"))
    |> assert_has(css(".driver__vehicle-details .driver-info-container", text: "No Address"))
  end

  feature "search next page works with radius", %{session: session} do
    insert(:driver, address: nil, first_name: "No", last_name: "Address")
    insert_list(22, :driver, first_name: "Has", last_name: "Address")

    session
    |> Admin.visit_page("markets/capacity")
    |> set_value(css("option[value='address']"), :selected)
    |> fill_in(text_field("dt_filter_capacity_pickup_address"),
      with: "520 Vine St., Cincinnati, OH"
    )
    |> fill_in(text_field("dt_filter_capacity_search_radius"), with: 300)
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 20))
    |> Admin.next_page()
    |> assert_has(css(".driver__vehicle-details", count: 2))
  end

  feature "display vehicle tag for has_lift_gate and has_pallet_gate ", %{session: session} do
    insert(:driver,
      first_name: "No",
      last_name: "Address",
      vehicles: [
        build(:vehicle,
          vehicle_class: 1,
          year: 2012,
          make: "Somemake",
          model: "Somemodel",
          lift_gate: true,
          pallet_jack: true
        )
      ]
    )

    session
    |> Admin.visit_page("markets/capacity")
    |> set_value(css("option[value='address']"), :selected)
    |> assert_has(css(".driver__vehicle-details", count: 1))
    |> assert_has(css("[data-test-id='lift-gate']", text: "Lift Gate"))
    |> assert_has(css("[data-test-id='pallet-jack']", text: "Pallet Jack"))
  end
end
