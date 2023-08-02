defmodule FraytElixirWeb.Admin.CompaniesTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  alias FraytElixir.Accounts

  setup [:create_and_login_admin]

  feature "shows companies", %{session: session} do
    company = insert(:company, name: "Test Company", invoice_period: 17)
    address = insert(:address)

    location =
      insert(:location,
        store_number: "1234",
        company: company,
        location: "Downtown",
        email: "downtown@location.com",
        address: address,
        sales_rep: insert(:admin_user, name: "Some Admin")
      )

    shipper = insert(:shipper_with_location, location: location)
    insert_list(2, :match, state: :charged, shipper: shipper, amount_charged: 1000)
    insert(:match, state: :canceled, shipper: shipper, amount_charged: 2000, cancel_charge: 500)

    insert(:match,
      state: :admin_canceled,
      shipper: shipper,
      amount_charged: 2000,
      cancel_charge: nil
    )

    insert_list(4, :match, state: :pending, amount_charged: nil, cancel_charge: nil)
    shipper2 = insert(:shipper_with_location, location: location, first_name: "Someone")
    insert(:completed_match, shipper: shipper2, amount_charged: 5999)
    insert(:shipper, location: location, state: "disabled")
    insert(:shipper, location: location)
    assert {1, nil} = Accounts.update_company_metrics()

    session
    |> Admin.visit_page("companies")
    |> assert_has(css("td", text: "Test Company"))
    |> assert_has(css("[data-test-id='location-count']", text: "1"))
    |> assert_has(css("[data-test-id='shipper-count']", text: "3"))
    |> assert_has(css("[data-test-id='match-count']", text: "5"))
    |> assert_has(css("td", text: "84.99"))
  end

  @tag timeout: 90_000
  feature "toggles company extra info in mobile", %{session: session} do
    insert(:company, name: "Test Company 1", invoice_period: 54)
    insert(:company, name: "Test Company 2", invoice_period: 32)

    session
    |> resize_window(596, 882)
    |> Admin.visit_page("companies")
    |> refute_has(css("td", text: "54"))
    |> refute_has(css("td", text: "32"))
    |> Admin.toggle_show_more("Test Company 1")
    |> assert_has(css("td", text: "54"))
    |> refute_has(css("td", text: "32"))
    |> Admin.toggle_show_more("Test Company 2")
    |> refute_has(css("td", text: "54"))
    |> assert_has(css("td", text: "32"))
    |> Admin.toggle_show_more("Test Company 2")
    |> refute_has(css("td", text: "54"))
    |> refute_has(css("td", text: "32"))
  end

  @tag timeout: 90_000
  feature "sort companies by match, shipper, and location counts and by name and net terms/invoice period and revenue",
          %{session: session} do
    admin1 =
      insert(:admin_user,
        name: "Admin User",
        role: "sales_rep",
        user: build(:user, email: "some@admin.com")
      )

    admin2 =
      insert(:admin_user,
        name: nil,
        role: "sales_rep",
        user: build(:user, email: "someother@admin.com")
      )

    admin3 = insert(:admin_user, name: "Another User", role: "sales_rep")
    b = insert(:company, name: "Company B", invoice_period: 3, sales_rep: admin1)
    d = insert(:company, name: "Company D", invoice_period: 10, sales_rep: admin2)
    insert(:company, name: "Company A", invoice_period: 1, sales_rep: admin3)
    c = insert(:company, name: "Company C", invoice_period: 15, sales_rep: admin3)
    locations_c = insert_list(3, :location, company: c)
    locations_b = insert_list(5, :location, company: b)
    location_d = insert(:location, company: d)
    shippers_b = insert_list(7, :shipper_with_location, location: Enum.at(locations_b, 3))
    shippers_d = insert_list(2, :shipper_with_location, location: location_d)
    shippers_c = insert_list(15, :shipper_with_location, location: Enum.at(locations_c, 1))
    shippers_b2 = insert_list(3, :shipper_with_location, location: Enum.at(locations_b, 2))

    insert_list(3, :completed_match,
      shipper: Enum.at(shippers_b, 4),
      amount_charged: 1000
    )

    insert_list(6, :completed_match,
      shipper: Enum.at(shippers_d, 1),
      amount_charged: 2200
    )

    insert_list(2, :completed_match,
      shipper: Enum.at(shippers_c, 0),
      amount_charged: 3200
    )

    insert(:completed_match, shipper: Enum.at(shippers_b2, 1), amount_charged: 1204)

    session
    |> Admin.visit_page("companies")
    |> Admin.test_sorting("Company Name", "company-name", 4, "Company A")
    |> Admin.test_sorting("Company Name", "company-name", 4, "Company D")
    |> Admin.test_sorting("Locations", "company-name", 4, "Company A")
    |> Admin.test_sorting("Locations", "company-name", 4, "Company B")
    |> Admin.test_sorting("Shippers", "company-name", 4, "Company A")
    |> Admin.test_sorting("Shippers", "company-name", 4, "Company C")
    |> Admin.test_sorting("Matches", "company-name", 4, "Company A")
    |> Admin.test_sorting("Matches", "company-name", 4, "Company D")
    |> Admin.test_sorting("Net Terms", "company-name", 4, "Company A")
    |> Admin.test_sorting("Net Terms", "company-name", 4, "Company C")
    |> Admin.test_sorting("Revenue", "company-name", 4, "Company A")
    |> Admin.test_sorting("Revenue", "company-name", 4, "Company D")
  end

  feature "companies pagination", %{session: session} do
    insert(:company, name: "Whatever")
    insert_list(10, :company, name: "Some Company")

    session
    |> Admin.visit_page("companies")
    |> Admin.sort_by("Company Name")
    |> assert_has(css("[data-test-id='company-name']", text: "Some Company", count: 10))
    |> Admin.next_page(2)
    |> assert_has(css("[data-test-id='company-name']", text: "Whatever"))
    |> Admin.previous_page(2)
    |> assert_has(css("[data-test-id='company-name']", text: "Some Company", count: 10))
  end

  feature "search companies without affecting metrics", %{session: session} do
    company1 = insert(:company, name: "Something Else")

    company2 = insert(:company, name: "Company First")

    insert(:location, company: company1, location: "Location 1")

    insert(:location, company: company2, location: "Location 2")

    insert(:location, company: company1, location: "Location 1")

    insert(:location, company: company2, location: "Location 2")

    assert {_, nil} = FraytElixir.Accounts.update_company_metrics()

    session
    |> Admin.visit_page("companies")
    |> assert_has(css("[data-test-id='company-name']", text: "Company First"))
    |> assert_has(css("[data-test-id='company-name']", text: "Something Else"))
    |> assert_has(css("[data-test-id='location-count']", text: "2", count: 2))
    |> Admin.search("Company")
    |> assert_has(css("[data-test-id='company-name']", text: "Company First"))
    |> refute_has(css("[data-test-id='company-name']", text: "Something Else"))
    |> assert_has(css("[data-test-id='location-count']", text: "2", count: 1))
  end

  feature "search doesn't change order", %{session: session} do
    insert(:company, name: "Company A")
    insert(:company, name: "Company B")

    session
    |> Admin.visit_page("companies")
    |> Admin.test_sorting("Company Name", "company-name", 2, "Company A")
    |> Admin.test_sorting("Company Name", "company-name", 2, "Company B")
    |> Admin.search("")
    |> Admin.assert_has_text(css("[data-test-id='company-name']", count: 2, at: 0), "Company B")
  end
end
