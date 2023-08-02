defmodule FraytElixirWeb.Admin.ShippersTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  use Bamboo.Test, shared: true

  setup [:create_and_login_admin]

  @tag :feature
  feature "displays shippers", %{session: session} do
    admin = insert(:admin_user, role: :sales_rep, name: "Whatever Name")

    shipper =
      insert(:shipper,
        first_name: "Abe",
        last_name: "Miller",
        company: "Frayt",
        commercial: true,
        referrer: "Employer",
        phone: "5555555555",
        stripe_customer_id: "cus_H6mGCsJfQQlALU (), (), ()",
        sales_rep: admin
      )

    insert(:credit_card, shipper: shipper)

    session
    |> Admin.visit_page("shippers")
    |> assert_has(css("td", text: "Abe Miller"))
    |> assert_has(css("td", text: "Frayt"))
    |> assert_has(css("td", text: "Whatever Name"))
    |> assert_has(css("td", text: "Business"))
    |> Admin.toggle_show_more("Abe Miller")
    |> assert_has(css("td", text: shipper.user.email))
    |> assert_has(css("td", text: "(555)555-5555"))
    |> assert_has(css("td", text: "708 Walnut St"))
    |> assert_has(css("td", text: "Cincinnati, OH 45202"))
    |> assert_has(css("td", text: "Employer"))
    |> assert_has(css("td", text: "XXXX XXXX XXXX 4242"))
    |> assert_has(css("td", text: "cus_H6mGCsJfQQlALU (), (), ()"))
  end

  @tag timeout: 90_000
  feature "toggles shipper show mores correctly", %{session: session} do
    shipper1 = insert(:shipper, first_name: "Abe", last_name: "Miller", company: "Frayt")
    shipper2 = insert(:shipper, first_name: "Sara", last_name: "Jones", company: "Gaslight")

    session
    |> Admin.visit_page("shippers")
    |> assert_has(css("td", text: "Abe Miller"))
    |> assert_has(css("td", text: "Sara Jones"))
    |> refute_has(css("td", text: shipper1.user.email))
    |> refute_has(css("td", text: shipper2.user.email))
    |> Admin.toggle_show_more("Abe Miller")
    |> assert_has(css("td", text: shipper1.user.email))
    |> refute_has(css("td", text: shipper2.user.email))
    |> Admin.toggle_show_more("Sara Jones")
    |> assert_has(css("td", text: shipper2.user.email))
    |> refute_has(css("td", text: shipper1.user.email))
    |> Admin.toggle_show_more("Sara Jones")
    |> refute_has(css("td", text: shipper2.user.email))
    |> refute_has(css("td", text: shipper1.user.email))
  end

  feature "sort shippers by name and company and last active and sales rep", %{session: session} do
    sales_rep_1 =
      insert(:admin_user,
        name: "Admin One",
        role: "sales_rep",
        user: build(:user, email: "admin1@email.com")
      )

    sales_rep_2 =
      insert(:admin_user, role: "sales_rep", user: build(:user, email: "admin2@email.com"))

    insert(:shipper,
      first_name: "Zora",
      last_name: "Jones",
      company: "Company A",
      updated_at: ~N[2000-01-01 23:00:07],
      sales_rep: sales_rep_1
    )

    insert(:shipper,
      first_name: "Abe",
      last_name: "Miller",
      company: "Company C",
      updated_at: ~N[2000-12-01 23:00:07],
      sales_rep: sales_rep_2
    )

    insert(:shipper,
      first_name: "Abe",
      last_name: "Smith",
      company: "Company B",
      updated_at: ~N[2000-01-03 23:00:07],
      sales_rep: nil
    )

    session
    |> Admin.visit_page("shippers")
    |> refute_has(css(".material-icons", text: "arrow_upward"))
    |> assert_has(css(".material-icons", text: "arrow_downward"))
    |> Admin.test_sorting("Name", "shipper-name", 3, "Abe Miller")
    |> assert_has(
      css("[data-test-id='sort-by-shipper_name'] .material-icons", text: "arrow_upward")
    )
    |> Admin.test_sorting("Name", "shipper-name", 3, "Zora")
    |> assert_has(
      css("[data-test-id='sort-by-shipper_name'] .material-icons", text: "arrow_downward")
    )
    |> Admin.test_sorting("Company", "shipper-company", 3, "Company A")
    |> refute_has(css("[data-test-id='sort-by-shipper'] .material-icons", text: "arrow_downward"))
    |> refute_has(css("[data-test-id='sort-by-shipper'] .material-icons", text: "arrow_upward"))
    |> assert_has(css("[data-test-id='sort-by-company'] .material-icons", text: "arrow_upward"))
    |> Admin.test_sorting("Company", "shipper-company", 3, "Company C")
    |> assert_has(css("[data-test-id='sort-by-company'] .material-icons", text: "arrow_downward"))
    |> Admin.test_sorting("Company", "shipper-company", 3, "Company A")
    |> Admin.test_sorting("Name", "shipper-name", 3, "Abe Miller")
    |> Admin.test_sorting("Last Active", "shipper-name", 3, "Zora Jones")
    |> Admin.test_sorting("Last Active", "shipper-name", 3, "Abe Miller")
    |> Admin.test_sorting("Sales Rep", "shipper-name", 3, "Zora Jones")
    |> Admin.test_sorting("Sales Rep", "shipper-name", 3, "Abe Smith")
  end

  feature "shippers pagination", %{session: session} do
    insert(:shipper, first_name: "Abe", last_name: "Smith")
    insert_list(20, :shipper, first_name: "Zora", last_name: "Jones")

    session
    |> Admin.visit_page("shippers")
    |> Admin.sort_by("Name")
    |> Admin.sort_by("Name")
    |> assert_has(css("[data-test-id='shipper-name']", text: "Zora Jones", count: 20))
    |> Admin.next_page(2)
    |> assert_has(css("[data-test-id='shipper-name']", text: "Abe Smith"))
    |> Admin.previous_page(2)
    |> assert_has(css("[data-test-id='shipper-name']", text: "Zora Jones", count: 20))
  end

  feature "shippers search by name or email, company name, sales rep name or email", %{
    session: session
  } do
    insert(:shipper,
      first_name: "Zora",
      last_name: "Jones",
      company: "Some Company"
    )

    insert(:shipper,
      first_name: "Abe",
      last_name: "Smith",
      sales_rep: nil,
      user: build(:user, email: "shipper@email.com")
    )

    session
    |> Admin.visit_page("shippers")
    |> assert_has(css("[data-test-id='shipper-name']", text: "Zora Jones"))
    |> assert_has(css("[data-test-id='shipper-name']", text: "Abe Smith"))
    |> Admin.search("Zora")
    |> assert_has(css("[data-test-id='shipper-name']", text: "Zora Jones"))
    |> refute_has(css("[data-test-id='shipper-name']", text: "Abe Smith"))
    |> Admin.search("shipper@email.com")
    |> refute_has(css("[data-test-id='shipper-name']", text: "Zora Jones"))
    |> assert_has(css("[data-test-id='shipper-name']", text: "Abe Smith"))
  end

  feature "changing page after search doesn't negate search", %{session: session} do
    insert(:shipper, first_name: "Zora", last_name: "Jones")
    insert_list(21, :shipper, first_name: "Abe", last_name: "Smith")

    session
    |> Admin.visit_page("shippers")
    |> Admin.search("Abe")
    |> assert_has(css("[data-test-id='shipper-name']", text: "Abe Smith", count: 20))
    |> Admin.next_page(2)
    |> refute_has(css("[data-test-id='shipper-name']", text: "Zora Jones"))
    |> assert_has(css("[data-test-id='shipper-name']", text: "Abe Smith", count: 1))
  end

  feature "modal opens and closes", %{session: session} do
    session
    |> Admin.visit_page("shippers")
    |> refute_has(css(".modal"))
    |> click(css("[data-test-id='add-shipper']"))
    |> assert_has(css(".modal"))
    |> click(css("a", text: "Cancel"))
    |> refute_has(css(".modal"))
    |> click(css("[data-test-id='add-shipper']"))
    |> assert_has(css(".modal"))
    |> click(css("[phx-click='close_modal']", count: 2, at: 0))
    |> refute_has(css(".modal"))
  end

  feature "search doesn't change order", %{session: session} do
    insert(:shipper, first_name: "Abe", last_name: "Smith")
    insert(:shipper, first_name: "Zora", last_name: "Jones")

    session
    |> Admin.visit_page("shippers")
    |> Admin.test_sorting("Name", "shipper-name", 2, "Abe Smith")
    |> Admin.test_sorting("Name", "shipper-name", 2, "Zora Jones")
    |> Admin.search("")
    |> Admin.assert_has_text(css("[data-test-id='shipper-name']", count: 2, at: 0), "Zora Jones")
  end

  feature "edit shipper", %{session: session} do
    admin = insert(:admin_user, name: nil, role: :sales_rep)
    insert(:shipper, state: "approved", first_name: "Initial", last_name: "Name")

    session
    |> Admin.visit_page("shippers")
    |> assert_has(css("[data-test-id='shipper-name']", count: 1))
    |> assert_has(css("[data-test-id='shipper-name']", text: "Initial Name"))
    |> Admin.toggle_show_more("Initial Name")
    |> click(css("a", text: "Edit Shipper"))
    |> set_value(css("option[value='#{admin.id}']"), :selected)
    |> fill_in(text_field("shipper_first_name"), with: "New")
    |> fill_in(text_field("shipper_last_name"), with: "Information")
    |> fill_in(text_field("shipper_user_email"), with: "")
    |> click(css("button", text: "Save Edits"))
    |> assert_has(css(".error", count: 1, text: "can't be blank"))
    |> fill_in(text_field("shipper_user_email"), with: "new@email.com")
    |> click(css("button", text: "Save Edits"))
    |> assert_has(css("[data-test-id='shipper-name']", count: 1))
    |> assert_has(css("[data-test-id='shipper-name']", text: "New Information"))
    |> assert_has(css("td", text: "new@email.com"))
    |> assert_has(css("td", text: admin.user.email))
  end

  feature "add a shipper", %{session: session} do
    admin = insert(:admin_user, name: "Sales Name", role: "sales_rep")

    session
    |> Admin.visit_page("shippers")
    |> click(css("[data-test-id='add-shipper']"))
    |> fill_in(text_field("shipper_last_name"), with: "Information")
    |> fill_in(text_field("shipper_user_email"), with: "new@email.com")
    |> fill_in(text_field("shipper_phone"), with: "5432346436")
    |> fill_in(text_field("shipper_address_address"), with: "123 Some Place")
    |> fill_in(text_field("shipper_address_city"), with: "")
    |> fill_in(text_field("shipper_address_state"), with: "TX")
    |> fill_in(text_field("shipper_address_zip"), with: "45202")
    |> set_value(css("option[value='#{admin.id}']"), :selected)
    |> click(css("button", text: "Invite Shipper"))
    |> assert_has(css(".error", count: 1, text: "can't be blank"))
    |> fill_in(text_field("shipper_first_name"), with: "New")
    |> fill_in(text_field("shipper_address_city"), with: "Houston")
    |> click(css("button", text: "Invite Shipper"))
    |> assert_has(css("[data-test-id='shipper-name']", count: 1))
    |> assert_has(css("[data-test-id='shipper-name']", text: "New Information"))
    |> assert_has(css("td", text: "Sales Name"))
    |> Admin.toggle_show_more("New Information")
    |> assert_has(css("td", text: "new@email.com"))
    |> assert_has(css("td", text: "(543)234-6436"))
    |> assert_has(css("td", text: "123 Some Place"))
    |> assert_has(css("td > div", text: "Houston, TX 45202"))

    assert_email_delivered_with(
      subject: "Important next steps with your FRAYT account",
      to: [nil: "new@email.com"]
    )
  end

  feature "reset shipper password from admin sends email to shipper", %{session: session} do
    insert(:shipper,
      first_name: "Reset",
      last_name: "Shipper",
      user: build(:user, email: "shipper@email.com")
    )

    session
    |> Admin.visit_page("shippers")
    |> Admin.toggle_show_more("Reset Shipper")
    |> click(css("a", text: "Reset Password"))
    |> assert_has(css("h3", text: "Reset Password"))
    |> assert_has(css("code", text: "shipper@email.com"))
    |> click(button("Yes, send"))
    |> assert_has(css("p", text: "Email sent"))
    |> click(button("OK"))

    assert_email_delivered_with(
      subject: "Reset Your Frayt Password",
      to: [nil: "shipper@email.com"]
    )
  end

  feature "disable and reactivate shipper", %{session: admin_session} do
    insert(:shipper,
      first_name: "Disableable",
      last_name: "Shipper",
      state: "disabled",
      user:
        build(:user,
          email: "disableable@shipper.com",
          password: "password",
          auth_via_bubble: false
        )
    )

    admin_session
    |> Admin.visit_page("shippers")
    |> refute_has(css("u-warning", text: "Disabled"))
    |> Admin.toggle_show_more("Disableable Shipper")
    |> set_value(css("#update_shipper_state_state option[value='approved']"), :selected)
    |> click(button("Yes"))
    |> assert_has(css("td > span", text: "Approved"))
    |> set_value(css("#update_shipper_state_state option[value='disabled']"), :selected)
    |> click(button("Yes"))
    |> refute_has(css("td", text: "Disabled"))
  end

  feature "shipper sales rep displays as company or location sales rep", %{session: session} do
    admin = insert(:admin_user, role: :sales_rep, name: "Whatever Name")
    location_with_rep = insert(:location, sales_rep: admin)
    company_with_rep = insert(:company, sales_rep: admin)
    location_without_rep = insert(:location, sales_rep: nil, company: company_with_rep)

    insert(:shipper,
      first_name: "Abe",
      last_name: "Miller",
      company: "Frayt",
      referrer: "Employer",
      phone: "5555555555",
      stripe_customer_id: "cus_H6mGCsJfQQlALU (), (), ()",
      sales_rep: nil,
      location: location_with_rep
    )

    insert(:shipper,
      first_name: "Abe",
      last_name: "Miller",
      company: "Frayt",
      referrer: "Employer",
      phone: "5555555555",
      stripe_customer_id: "cus_H6mGCsJfQQlALU (), (), ()",
      sales_rep: nil,
      location: location_without_rep
    )

    session
    |> Admin.visit_page("shippers")
    |> assert_has(css("td", text: "Whatever Name", count: 2))
  end

  @tag timeout: 90_000
  feature "show more works on mobile", %{session: session} do
    shipper1 =
      insert(:shipper,
        first_name: "First",
        last_name: "Shipper",
        stripe_customer_id: "cus_H6mGCsJfQQlALU"
      )

    shipper2 =
      insert(:shipper,
        first_name: "Last",
        last_name: "Shipper",
        stripe_customer_id: "cus_H6mGCsJfQQlFRE"
      )

    session
    |> resize_window(596, 882)
    |> Admin.visit_page("shippers")
    |> refute_has(css("td", text: shipper1.stripe_customer_id))
    |> refute_has(css("td", text: shipper2.stripe_customer_id))
    |> Admin.toggle_show_more("First Shipper")
    |> assert_has(css("td", text: shipper1.stripe_customer_id))
    |> refute_has(css("td", text: shipper2.stripe_customer_id))
    |> Admin.toggle_show_more("Last Shipper")
    |> refute_has(css("td", text: shipper1.stripe_customer_id))
    |> assert_has(css("td", text: shipper2.stripe_customer_id))
    |> Admin.toggle_show_more("First Shipper")
    |> refute_has(css("td", text: shipper2.stripe_customer_id))
    |> assert_has(css("td", text: shipper1.stripe_customer_id))
  end
end
