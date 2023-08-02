defmodule FraytElixirWeb.Admin.DriverShowTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  use Bamboo.Test, shared: true
  alias FraytElixir.Payments.DriverBonus
  alias FraytElixir.Drivers.{Driver, VehicleDocument}
  alias FraytElixirWeb.Test.FileHelper

  setup [:create_and_login_admin]

  feature "shows info on driver show page", %{session: session} do
    vehicle =
      build(:vehicle,
        make: "Some make",
        model: "Some model",
        year: "2020",
        license_plate: "ASD1234",
        vin: "D23K4IO3245KJ1235",
        cargo_area_width: 55,
        cargo_area_height: 36,
        cargo_area_length: 64,
        door_width: 35,
        door_height: 42,
        wheel_well_width: 10,
        max_cargo_weight: 85,
        vehicle_class: 2
      )

    driver =
      insert(:driver,
        birthdate: "1987-05-31T00:00:00-05:00",
        first_name: "Test",
        last_name: "Driver",
        license_number: "RE234123",
        phone_number: "+12345678901",
        ssn: "555443333",
        address: %{address: "123 Some St.", state: "OH", city: "Cincinnati", zip: "45202"},
        vehicles: [vehicle]
      )

    insert(:match, driver: driver, state: "canceled", driver_total_pay: 2000)
    insert(:match, driver: driver, state: "accepted", driver_total_pay: 2000)
    insert(:match, driver: driver, state: "en_route_to_pickup", driver_total_pay: 2000)
    insert(:match, driver: driver, state: "picked_up", driver_total_pay: 2000)
    insert_list(2, :match, driver: driver, state: "charged", driver_total_pay: 2000)
    insert_list(3, :hidden_match, driver: driver)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> assert_has(css("h3", text: "Test Driver"))
    |> assert_has(css("p", text: "+1 234-567-8901"))
    |> assert_has(css("p", text: "RE234123"))
    |> assert_has(css("p", text: "***-**-3333"))
    |> assert_has(css("[data-test-id='address']", text: "123 Some St."))
    |> assert_has(css("p", text: "Cincinnati, OH 45202"))
    |> assert_has(css("p", text: driver.user.email))
    |> assert_has(css("p", text: "Some make"))
    |> assert_has(css("p", text: "Some model"))
    |> assert_has(css("p", text: "D23K4IO3245KJ1235"))
    |> assert_has(css("p", text: "ASD1234"))
    |> assert_has(css("p", text: "2020"))
    |> assert_has(css("p", text: "05/31/1987"))
    |> assert_has(css("[data-test-id='door_height']", text: "42\""))
    |> assert_has(css("[data-test-id='door_width']", text: "35\""))
    |> assert_has(css("[data-test-id='cargo_area_width']", text: "55\""))
    |> assert_has(css("[data-test-id='cargo_area_height']", text: "36\""))
    |> assert_has(css("[data-test-id='cargo_area_length']", text: "64\""))
    |> assert_has(css("[data-test-id='wheel_well_width']", text: "10\""))
    |> assert_has(css("[data-test-id='max_cargo_weight']", text: "85 lbs"))
    |> assert_has(css("[data-test-id='vehicle_type']", text: "Midsize"))
  end

  feature "adding penalties works", %{session: session} do
    driver = insert(:driver, penalties: 0)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> assert_has(css(".material-icons.u-light-gray", text: "highlight_off", count: 5))
    |> click(css("[phx-click='change_penalties'][phx-value-penaltynumber='4']"))
    |> assert_has(css(".material-icons.u-light-gray", text: "highlight_off"))
    |> assert_has(css(".material-icons.u-warning", text: "cancel", count: 4))
    |> click(css("[phx-click='change_penalties'][phx-value-penaltynumber='1']"))
    |> assert_has(css(".material-icons.u-warning", text: "cancel", count: 1))
    |> assert_has(css(".material-icons.u-light-gray", text: "highlight_off", count: 4))
    |> click(css("[phx-click='change_penalties'][phx-value-penaltynumber='1']"))
    |> assert_has(css(".material-icons.u-warning", text: "cancel", count: 0))
    |> assert_has(css(".material-icons.u-light-gray", text: "highlight_off", count: 5))
  end

  @tag timeout: 90_000
  feature "add notes to a driver", %{session: session} do
    driver = insert(:driver)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> refute_has(css(".button.button--primary", text: "Save"))
    |> refute_has(css(".button", text: "Cancel"))
    |> click(css("textarea"))
    |> assert_has(css(".button.button--primary", text: "Save"))
    |> assert_has(css(".button", text: "Cancel"))
    |> fill_in(text_field("driver-notes"), with: "This is a note.")
    |> click(css(".button.button--primary", text: "Save"))
    |> refute_has(css(".button.button--primary", text: "Save"))
    |> refute_has(css(".button", text: "Cancel"))
    |> Admin.assert_textarea_text("This is a note.")
    |> fill_in(text_field("driver-notes"), with: "This is another note.")
    |> click(css(".button", text: "Cancel"))
    |> refute_has(css(".button.button--primary", text: "Save"))
    |> refute_has(css(".button", text: "Cancel"))
    |> Admin.assert_textarea_text("This is a note.")
    |> Admin.refute_textarea_text("This is another note.")
    |> fill_in(text_field("driver-notes"), with: "")
    |> click(css(".button.button--primary", text: "Save"))
    |> refute_has(css(".button.button--primary", text: "Save"))
    |> refute_has(css(".button", text: "Cancel"))
    |> Admin.refute_textarea_text("This is a note.")
  end

  feature "edit driver personal info via admin", %{session: session} do
    %{id: driver_id, state: state} =
      driver = insert(:driver, user: build(:user), address: build(:address), ssn: nil)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> click(css("button", text: "Edit Personal Information"))
    |> fill_in(text_field("driver_first_name"), with: "Changed")
    |> fill_in(text_field("driver_last_name"), with: "Name")
    |> fill_in(text_field("driver_user_email"), with: "")
    |> click(css("button", text: "Update Driver"))
    |> assert_has(css(".error", text: "can't be blank"))
    |> fill_in(text_field("driver_user_email"), with: "somenew@email.com")
    |> fill_in(text_field("driver_phone_number"), with: "+19345238543")
    |> click(css("button", text: "Specify Details"))
    |> fill_in(text_field("driver_address_address"), with: "4533 Ruebel Place")
    |> clear(text_field("driver_address_address2"))
    |> fill_in(text_field("driver_address_city"), with: "Cincinnati")
    |> set_value(select("driver_address_state_code"), "OH")
    |> fill_in(text_field("driver_address_zip"), with: "45211")
    |> fill_in(text_field("driver_license_number"), with: "ZZ111222")
    |> fill_in(text_field("driver_birthdate"), with: "03/03/2010")
    |> click(css("button", text: "Update Driver"))
    |> assert_has(css("h3", text: "Changed Name"))
    |> assert_has(css("p", text: "somenew@email.com"))
    |> assert_has(css("p", text: "+1 934-523-8543"))
    |> assert_has(css("[data-test-id='address']", text: "4533 Ruebel Place"))
    |> refute_has(css("[data-test-id='address2']"))
    |> assert_has(css("p", text: "Cincinnati, OH 45211"))
    |> assert_has(css("p", text: "ZZ111222"))
    |> assert_has(css("p", text: "03/03/2010"))
    |> click(css("button", text: "Edit Personal Information"))
    |> fill_in(text_field("driver_ssn"), with: "111-11-1111")
    |> click(css("button", text: "Update Driver"))
    |> assert_has(css("p", text: "***-**-1111"))

    assert %{state: ^state} = FraytElixir.Drivers.get_driver!(driver_id)
  end

  feature "reset driver password from admin sends email to driver", %{session: session} do
    driver =
      insert(:driver,
        first_name: "Reset",
        last_name: "Driver",
        user: build(:user, email: "driver@email.com")
      )

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> click(css("a", text: "Reset Password"))
    |> assert_has(css("h3", text: "Reset Password"))
    |> assert_has(css("code", text: "driver@email.com"))
    |> click(button("Yes, send"))
    |> assert_has(css("p", text: "Email sent"))
    |> click(button("OK"))

    assert_email_delivered_with(
      subject: "Reset Your Frayt Password",
      to: [nil: "driver@email.com"]
    )
  end

  feature "disable and reinstate a driver account", %{session: session} do
    driver = insert(:driver, first_name: "Driver", last_name: "One")

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> refute_has(css("h3", text: "Driver One (Disabled)"))
    |> refute_has(css("a", text: "Reactivate Driver"))
    |> click(css("a", text: "Disable Driver"))
    |> fill_in(text_field("notes"), with: "This is an additional note.")
    |> click(button("Yes"))
    |> click(button("OK"))
    |> assert_has(css("h3", text: "Driver One (Disabled)"))
    |> refute_has(css("a", text: "Disable Driver"))
    |> refute_has(css("a", text: "Reset Password"))
    |> refute_has(css("a", text: "Pay Driver"))
    |> refute_has(css("a", text: "Edit Personal Information"))

    assert_email_delivered_with(
      subject: "Frayt Account Disabled",
      to: [nil: driver.user.email],
      text_body:
        "Frayt Account Disabled\nSorry, Driver One, your account has been disabled.\nThis is an additional note.\nPlease contact support for more information or to challenge this decision.\n\nThanks!\n- The Frayt Team\n"
    )

    session
    |> click(css("a", text: "Reactivate Driver"))
    |> click(button("Yes"))
    |> click(button("OK"))
    |> refute_has(css("h3", text: "Driver One (Disabled)"))
    |> assert_has(css("a", text: "Disable Driver"))
    |> assert_has(css("a", text: "Reset Password"))
    |> assert_has(css("a", text: "Pay Driver"))
    |> assert_has(css("button", text: "Edit Personal Information"))
    |> refute_has(css("a", text: "Reactivate Driver"))

    assert_email_delivered_with(
      subject: "Frayt Account Reactivated",
      to: [nil: driver.user.email],
      text_body:
        "Frayt Account Reactivated\nDriver One, your account has been reactivated.\nWhen you sign in, you can now see and accept matches.\n\nThanks!\n- The Frayt Team\n"
    )
  end

  feature "pay a driver a bonus amount", %{session: session, admin_user: admin_user} do
    driver = insert(:driver_with_wallet, first_name: "Driver", last_name: "Name")
    match1 = insert(:match, id: "272ef0d5-0c5a-4427-ae36-233bb9e4c479", driver: driver)
    match2 = insert(:match, id: "272ef0d5-0c5a-4427-ae36-233bb9e4c470", driver: driver)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> click(css("a", text: "Pay Driver Bonus"))
    |> fill_in(text_field("pay_driver_bonus_match_id"), with: "2725f0d5")
    |> click(button("Pay Driver"))
    |> assert_has(css(".error", text: "Enter a valid amount"))
    |> assert_has(css(".error", text: "Match not found"))
    |> fill_in(text_field("pay_driver_bonus_amount"), with: "12.05")
    |> fill_in(text_field("pay_driver_bonus_match_id"), with: "272ef0d5")
    |> click(button("Pay Driver"))
    |> assert_has(css(".error", text: "Multiple matches found"))
    |> assert_has(css("li a", text: "Choose match #{match1.id}"))
    |> click(css("li a", text: "Choose match #{match2.id}"))
    |> click(button("Pay Driver"))
    |> assert_has(Query.text("Bonus payment submitted"))

    %DriverBonus{created_by_id: created_by_id} =
      Repo.get_by(DriverBonus, driver_id: driver.id) |> Repo.preload(:created_by)

    assert created_by_id == admin_user.id
  end

  feature "cannot pay a driver who has no seller account", %{session: session} do
    driver = insert(:driver)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> click(css("a", text: "Pay Driver Bonus"))
    |> assert_has(css("[data-test-id='account-error']"))
  end

  feature "view vehicle photos", %{session: session} do
    %Driver{vehicles: [vehicle]} = driver = insert(:driver)

    [
      :back,
      :cargo_area,
      :drivers_side,
      :front,
      :insurance,
      :passengers_side,
      :registration,
      :vehicle_type
    ]
    |> Enum.map(fn descriptor ->
      VehicleDocument.changeset(%VehicleDocument{}, %{
        vehicle_id: vehicle.id,
        type: descriptor,
        document: %{filename: Atom.to_string(descriptor), binary: FileHelper.binary_image()}
      })
      |> Repo.insert()
    end)

    session
    |> Admin.visit_page("drivers/#{driver.id}")
    |> click(css("a", text: "View Photos"))
    |> assert_has(css("[alt='Back']"))
    |> assert_has(css("[alt='Front']"))
    |> assert_has(css("[alt='Driver Side']"))
    |> assert_has(css("[alt='Passenger Side']"))
    |> assert_has(css("[alt='Cargo Area']"))
    |> assert_has(css("[alt='Vehicle Type']"))
    |> refute_has(css("[alt='Insurance']"))
    |> refute_has(css("[alt='Registration']"))
  end
end
