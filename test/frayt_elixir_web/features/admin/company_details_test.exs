defmodule FraytElixirWeb.Admin.CompanyDetailsTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup [:create_and_login_admin]

  feature "edits a company", %{session: session} do
    admin = insert(:admin_user, role: "sales_rep", name: "An Admin")

    company =
      insert(:company,
        name: "Company Name",
        email: "company@email.com",
        invoice_period: 5,
        account_billing_enabled: false
      )

    session
    |> Admin.visit_page("companies/#{company.id}")
    |> click(css("a", text: "Edit Company"))
    |> fill_in(text_field("edit_company_form_name"), with: "")
    |> fill_in(text_field("edit_company_form_email"), with: "company@company.com")
    |> assert_has(css("[data-test-id='account-billing-unchecked']"))
    |> click(button("Update"))
    |> assert_has(css("[name=\"edit_company_form[name]\"] + .error", text: "can't be blank"))
    |> fill_in(text_field("edit_company_form_name"), with: "New Name")
    |> set_value(css("option[value='#{admin.id}']"), :selected)
    |> assert_has(css("[data-test-id='account-billing-unchecked']"))
    |> Admin.toggle_checkbox("[for='account_billing_enabled']")
    |> fill_in(text_field("edit_company_form[invoice_period]"), with: 12)
    |> click(button("Update"))
    |> assert_has(css("h3", text: "New Name"))
    |> assert_has(css("p", text: "company@company.com"))
    |> assert_has(css("p", text: "12"))
    |> assert_has(css("p", text: "An Admin"))
    |> click(css("a", text: "Edit Company"))
    |> assert_has(css("[data-test-id='account-billing-checked']"))
  end

  feature "edit company can reset shippers' sales reps",
          %{session: session} do
    admin1 = insert(:admin_user, role: "sales_rep", name: "Company Rep")
    admin2 = insert(:admin_user, role: "sales_rep", name: "Location1 Rep")
    admin3 = insert(:admin_user, role: "sales_rep", name: "Location2 Rep")
    company = insert(:company, name: "Some Company", sales_rep: admin1, invoice_period: 12)

    location1 =
      insert(:location,
        location: "Downtown",
        store_number: "452",
        company: company,
        sales_rep: admin2,
        invoice_period: nil
      )

    insert(:location,
      location: "Elsewhere",
      store_number: "545",
      company: company,
      sales_rep: admin3,
      invoice_period: 3
    )

    insert(:shipper_with_location, location: location1, sales_rep: nil)

    session
    |> Admin.visit_page("companies/#{company.id}")
    |> click(css("a", text: "Edit Company"))
    |> click(css("[for='replace-locations']"))
    |> click(button("Update"))
    |> Admin.visit_page("shippers")
    |> assert_has(css("td", text: "Company Rep"))
  end

  feature "add a location to an existing company", %{session: session} do
    admin1 = insert(:admin_user, role: "sales_rep", name: "Admin User")
    admin2 = insert(:admin_user, role: "sales_rep", name: nil)
    company = insert(:company, name: "Company A", sales_rep: admin2)

    session
    |> Admin.visit_page("companies/#{company.id}")
    |> click(css("[phx-click='add_location']"))
    |> fill_in(text_field("location-name"), with: "Location 1")
    |> fill_in(text_field("store-id"), with: "12345")
    |> fill_in(text_field("address-1"), with: "708 Walnut Street")
    |> fill_in(text_field("address-2"), with: "Floor 5")
    |> fill_in(text_field("city"), with: "Cincinnati")
    |> fill_in(text_field("state"), with: "OH")
    |> fill_in(text_field("zip-code"), with: "45202")
    |> fill_in(text_field("location-email"), with: "store12345@companya.com")
    |> fill_in(text_field("location-terms"), with: "10")
    |> Admin.assert_selected(css("option[value='#{admin2.id}']"))
    |> set_value(css("option[value='#{admin1.id}']"), :selected)
    |> click(button("Next"))
    |> click(button("Save"))
    |> assert_has(css("h3", text: "Company A"))
    |> assert_has(css("b", text: "Location 1"))
    |> assert_has(css("a", text: "store12345@companya.com"))
    |> assert_has(css("[data-test-id='active-shippers']", text: "0"))
    |> click(css("a", text: "View Details"))
    |> assert_has(css("p", text: "Admin User"))
  end
end
