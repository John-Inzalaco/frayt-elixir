defmodule FraytElixirWeb.Admin.UsersTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  alias Wallaby.Query

  setup [:create_and_login_admin]

  feature "user tabs work", %{session: session} do
    session
    |> Admin.visit_page("settings/profile")
    |> assert_has(css("h4", text: "My Profile"))
    |> Admin.assert_has_text(css(".active"), "Profile")
    |> click(css("[data-test-id=users-tab]"))
    |> refute_has(css("h4", text: "My Profile"))
    |> assert_has(css("h4", text: "Invite Users"))
    |> Admin.assert_has_text(css(".active"), "Users")
    |> click(css("[data-test-id=profile-tab]"))
    |> Admin.assert_has_text(css(".active"), "Profile")
    |> assert_has(css("h4", text: "My Profile"))
    |> refute_has(css("h4", text: "Invite Users"))
  end

  feature "invite users", %{session: session} do
    session
    |> Admin.visit_page("settings/users")
    |> fill_in(text_field("admin_user[name]"), with: "A Name")
    |> fill_in(text_field("admin_user[user][email]"), with: "some@email.com")
    |> set_value(select("admin_user[role]"), "member")
    |> click(button("Invite"))
    |> assert_has(css("td", text: "A Name"))
    |> assert_has(css("span", text: "some@email.com"))
  end

  feature "shows list of admins", %{session: session} do
    insert(:admin_user, disabled: true)
    insert_list(3, :admin_user, disabled: false)

    session
    |> Admin.visit_page("settings/users")
    |> assert_has(css("[data-test-id='admin-user']", count: 4))
    |> refute_has(css("span", text: "Disabled", count: 1))
  end

  feature "change password", %{session: session, admin_user: %{user: user}} do
    session
    |> Admin.visit_page("settings/profile")
    |> fill_in(text_field("password_form[old_password]"), with: user.password)
    |> fill_in(text_field("password_form[new_password]"), with: "asdf12@4")
    |> fill_in(text_field("password_form[confirm_password]"), with: "asdf12@4")
    |> click(button("Save"))
    |> assert_has(css(".success", text: "Password changed"))
  end

  feature "edit profile", %{session: session} do
    admin =
      insert(:admin_user,
        role: "sales_rep",
        name: nil,
        user: build(:user, email: "some@email.com", password: "password")
      )

    session
    |> Admin.visit_page("settings/profile")
    |> click(css("a", text: "Edit Profile"))
    |> fill_in(text_field("admin_user_name"), with: "Edited Admin")
    |> fill_in(text_field("admin_user_user_email"), with: "another@admin.com")
    |> click(button("Update Profile"))
    |> assert_has(css("p", text: "Edited Admin"))
    |> assert_has(css("p", text: "another@admin.com"))
    |> logout_user()
    |> login_user(admin.user)
    |> Admin.visit_page("settings/profile")
    |> click(css("a", text: "Edit Profile"))
    |> fill_in(text_field("admin_user_name"), with: "Edited SalesRep")
    |> fill_in(text_field("admin_user_user_email"), with: "another@salesrep.com")
    |> click(button("Update Profile"))
    |> assert_has(css("p", text: "Edited SalesRep"))
    |> assert_has(css("p", text: "another@salesrep.com"))
  end

  feature "edit admin users", %{session: session} do
    insert(:admin_user,
      role: "sales_rep",
      name: nil,
      user: build(:user, email: "some@email.com", password: "password")
    )

    session
    |> Admin.visit_page("settings/profile")
    |> click(css("a", text: "Users"))
    |> assert_has(css("td", text: "Initial User"))
    |> assert_has(css("span", text: "initial@admin.com"))
    |> assert_has(css("td", text: "Admin"))
    |> assert_has(css("td", text: "User 2"))
    |> assert_has(css("span", text: "some@email.com"))
    |> assert_has(css("td", text: "Sales Rep"))
    |> assert_has(css("span", text: "Goal: $0.00"))
    |> click(css("td[phx-click='edit_admin']", count: 2, at: 0))
    |> fill_in(text_field("admin_user_name", count: 2, at: 1), with: "Edited Admin")
    |> fill_in(text_field("admin_user_phone_number", count: 2, at: 1), with: "+19372057000")
    |> set_value(Query.select("admin_user_role", count: 2, at: 1), "network_operator")
    |> click(button("Save Edits"))
    |> assert_has(css("td", text: "Edited Admin"))
    |> assert_has(css("span", text: "initial@admin.com"))
    |> assert_has(css("td", text: "Network Operator"))
    |> click(css("td[phx-click='edit_admin']", count: 2, at: 1))
    |> fill_in(text_field("admin_user_name", count: 2, at: 1), with: "Edited SalesRep")
    |> assert_has(text_field("admin_user_sales_goal"))
    |> set_value(Query.select("admin_user_role", count: 2, at: 1), "network_operator")
    |> refute_has(text_field("admin_user_sales_goal"))
    |> set_value(Query.select("admin_user_role", count: 2, at: 1), "sales_rep")
    |> assert_has(text_field("admin_user_sales_goal"))
    |> fill_in(text_field("admin_user_sales_goal"), with: "321000")
    |> click(button("Save Edits"))
    |> assert_has(css("td", text: "Edited SalesRep"))
    |> assert_has(css("span", text: "some@email.com"))
    |> assert_has(css("td", text: "Sales Rep"))
    |> assert_has(css("span", text: "Goal: $321,000.00"))
  end
end
