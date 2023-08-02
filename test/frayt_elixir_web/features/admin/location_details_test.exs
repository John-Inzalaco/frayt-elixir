defmodule FraytElixirWeb.Admin.LocationDetailsTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup [:create_and_login_admin]

  feature "adds shippers to existing locations", %{session: session} do
    company = insert(:company, name: "Some Company")
    location = insert(:location, location: "Downtown", company: company)

    existing_shipper =
      insert(:shipper,
        first_name: "Existing",
        last_name: "Shipper",
        phone: "3214325432",
        user: build(:user)
      )

    existing_shipper_with_location =
      insert(:shipper_with_location,
        first_name: "Location",
        last_name: "Shipper",
        phone: "3214325432",
        location: build(:location),
        user: build(:user)
      )

    non_shipper = insert(:driver, user: build(:user))

    session
    |> Admin.visit_page("companies/#{company.id}/locations/#{location.id}")
    |> click(css("button", text: "+ Add Shipper"))
    |> fill_in(text_field("search_shipper_email_1"), with: existing_shipper.user.email)
    |> click(css("button", text: "Add Shipper", count: 2, at: 1))
    |> assert_has(css("b", text: "Existing Shipper"))
    |> click(css("button", text: "+ Add Shipper"))
    |> fill_in(text_field("search_shipper_email_1"), with: "new_email@example.com")
    |> click(css("button", text: "Add Shipper", count: 2, at: 1))
    |> assert_has(css("p", text: "Shipper does not exist"))
    |> fill_in(text_field("search_shipper_email_1"), with: non_shipper.user.email)
    |> click(css("button", text: "Add Shipper", count: 2, at: 1))
    |> assert_has(css("p", text: "Shipper does not exist"))
    |> fill_in(text_field("search_shipper_email_1"),
      with: existing_shipper_with_location.user.email
    )
    |> click(css("button", text: "Add Shipper", count: 2, at: 1))
    |> assert_has(css("p", text: "Shipper is already assigned to a location"))
    |> click(css("a", text: "Move to this location"))
    |> click(css("button", text: "Add Shipper", count: 2, at: 1))
    |> assert_has(css("b", text: "Location Shipper"))
  end

  feature "delete a shipper from a location", %{session: session} do
    company = insert(:company, name: "Test Company", invoice_period: 17)
    location = insert(:location, company: company)

    shipper =
      insert(:shipper_with_location,
        first_name: "Random",
        last_name: "Shipper",
        phone: "4325436543",
        location: location
      )

    session
    |> Admin.visit_page("companies/#{company.id}/locations/#{location.id}")
    |> assert_has(css("b", text: "Random Shipper"))
    |> click(css("[phx-click='remove_shipper_#{shipper.id}']"))
    |> refute_has(css("b", text: "Random Shipper"))
  end

  feature "edits location on company", %{session: session} do
    company = insert(:company, name: "Some Company")
    location = insert(:location, location: "Downtown", store_number: "324", company: company)
    insert(:location, location: "Elsewhere", store_number: "3241", company: company)
    admin = insert(:admin_user, name: "An Admin", role: "sales_rep")

    session
    |> Admin.visit_page("companies/#{company.id}/locations/#{location.id}")
    |> click(css("a", text: "Edit Location"))
    |> fill_in(text_field("edit_location_form[location]"), with: "")
    |> fill_in(text_field("edit_location_form[address]"), with: "")
    |> fill_in(text_field("edit_location_form[city]"), with: "")
    |> fill_in(text_field("edit_location_form[state]"), with: "")
    |> fill_in(text_field("edit_location_form[zip]"), with: "")
    |> click(button("Save Edits"))
    |> assert_has(css(".error", text: "can't be blank"))
    |> assert_has(css(".error", text: "is invalid"))
    |> fill_in(text_field("edit_location_form[location]"), with: "Updated Name")
    |> fill_in(text_field("edit_location_form[address]"), with: "4533 Ruebel Place")
    |> fill_in(text_field("edit_location_form[address2]"), with: "")
    |> fill_in(text_field("edit_location_form[store_number]"), with: "543")
    |> fill_in(text_field("edit_location_form[city]"), with: "Cincinnati")
    |> fill_in(text_field("edit_location_form[state]"), with: "Ohio")
    |> fill_in(text_field("edit_location_form[zip]"), with: "45211")
    |> set_value(css("option[value='#{admin.id}']"), :selected)
    |> fill_in(text_field("edit_location_form[email]"), with: "new@updated.com")
    |> fill_in(text_field("edit_location_form[invoice_period]"), with: "13")
    |> click(button("Save Edits"))
    |> assert_has(css("[data-test-id='address']", text: "4533 Ruebel Place"))
    |> assert_has(css("[data-test-id='city-state-zip']", text: "Cincinnati, OH 45211"))
    |> assert_has(css("p", text: "new@updated.com"))
    |> assert_has(css("p", text: "13"))
    |> assert_has(css("h3", text: "Updated Name (#543)"))
    |> assert_has(css("p", text: "An Admin"))
  end

  feature "edit location can reset shippers' sales reps", %{session: session} do
    admin2 = insert(:admin_user, role: "sales_rep", name: "Location1 Rep")
    admin3 = insert(:admin_user, role: "sales_rep", name: "Shipper Rep")

    company = insert(:company, name: "Some Company")
    downtown = insert(:location, location: "Downtown", company: company, sales_rep: admin2)
    insert(:shipper, location: downtown, sales_rep: admin3)

    session
    |> Admin.visit_page("companies/#{company.id}/locations/#{downtown.id}")
    |> click(css("a", text: "Edit Location"))
    |> click(button("Save Edits"))
    |> Admin.visit_page("shippers")
    |> assert_has(css("td", text: "Location1 Rep"))
  end

  feature "add and edit a schedule", %{session: session} do
    %{id: company_id, locations: [%{id: location_id}]} = insert(:company_with_location)

    {:ok, pickup_time} =
      Timex.Format.DateTime.Formatters.Default.format(~U[2020-10-15 19:45:00Z], "{0h12}:{0m}{AM}")

    session =
      session
      |> Admin.visit_page("companies/#{company_id}/locations/#{location_id}")
      |> click(button("Add Schedule"))
      |> fill_in(text_field("schedule_form_tuesday"), with: pickup_time)
      |> fill_in(text_field("schedule_form_max_drivers"), with: "6")
      |> fill_in(text_field("schedule_form_min_drivers"), with: "3")
      |> fill_in(text_field("schedule_form_sla"), with: "2")
      |> click(button("Save Schedule"))

    :timer.sleep(200)

    session
    |> assert_has(css("[data-test-id='tuesday-pickup']", text: "PM"))
    |> assert_has(css("[data-test-id='wednesday-pickup']", text: "-"))
    |> assert_has(css("[data-test-id='sla']", text: "2"))
    |> assert_has(css("[data-test-id='min-drivers']", text: "3"))
    |> assert_has(css("[data-test-id='max-drivers']", text: "6"))
    |> click(button("Edit Schedule"))
    |> fill_in(text_field("schedule_form_wednesday"), with: pickup_time)
    |> fill_in(text_field("schedule_form_max_drivers"), with: "7")
    |> fill_in(text_field("schedule_form_min_drivers"), with: "2")
    |> fill_in(text_field("schedule_form_sla"), with: "3")
    |> click(button("Save Edits"))
    |> assert_has(css("[data-test-id='wednesday-pickup']", text: "PM"))
    |> assert_has(css("[data-test-id='sla']", text: "3"))
    |> assert_has(css("[data-test-id='min-drivers']", text: "2"))
    |> assert_has(css("[data-test-id='max-drivers']", text: "7"))
  end

  feature "add and remove drivers from fleet", %{session: session} do
    [driver1, driver2, driver3] = insert_list(3, :driver)

    schedule =
      insert(:schedule, drivers: [driver3], location: build(:location, company: build(:company)))

    session
    |> Admin.visit_page(
      "companies/#{schedule.location.company_id}/locations/#{schedule.location_id}"
    )
    |> assert_has(css(".header--inline", text: "Fleet Size (1)"))
    |> assert_has(css("a", text: driver3.user.email))
    |> click(css("a", text: "+ Add Driver"))
    |> fill_in(text_field("search_driver_email_1"), with: driver1.user.email)
    |> click(css("a", text: "+ Add Another"))
    |> fill_in(text_field("search_driver_email_2"), with: driver2.user.email)
    |> click(button("Add Drivers"))
    |> assert_has(css("a", text: driver1.user.email))
    |> assert_has(css("a", text: driver2.user.email))
    |> assert_has(css("a", text: driver3.user.email))
    |> click(css("[phx-click='remove_driver_#{driver2.id}']"))
    |> assert_has(css("a", text: driver1.user.email))
    |> refute_has(css("a", text: driver2.user.email))
    |> assert_has(css("a", text: driver3.user.email))
  end
end
