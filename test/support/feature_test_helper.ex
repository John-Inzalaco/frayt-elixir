defmodule FraytElixirWeb.Test.FeatureTestHelper do
  import FraytElixir.Factory
  use Wallaby.DSL
  import Wallaby.Query
  alias FraytElixir.Accounts.{Shipper, User, AdminUser}
  alias FraytElixirWeb.Test.SessionPage
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  def login_as_shipper(%{session: session}) do
    shipper = insert(:shipper)
    credit_card = insert(:credit_card, shipper: shipper)
    session = session |> login_as_shipper(shipper)
    {:ok, shipper: shipper, credit_card: credit_card, session: session}
  end

  def login_as_shipper(session, %Shipper{user: %User{email: email}}) do
    session
    |> visit("/")
    |> click(css("#show-login"))
    |> fill_in(text_field("email"), with: email)
    |> fill_in(text_field("password"), with: "password")
    |> click(css("button[type='submit']"))
    |> assert_has(css(".pageTitle", text: "Ship"))
  end

  def login_user(session, %User{email: email, password: password}) do
    session
    |> SessionPage.visit_page()
    |> SessionPage.enter_credentials(email, password)
  end

  def logout_user(session) do
    session
    |> Admin.visit_page("settings/profile")
    |> click(css("a", text: "Sign Out"))
  end

  def create_and_login_admin(%{sessions: [session1 | other_sessions]}) do
    %AdminUser{user: %User{email: email, password: password}} =
      admin_user =
      insert(:admin_user,
        name: "Initial User",
        role: "admin",
        user: build(:user, email: "initial@admin.com")
      )

    session1 =
      session1
      |> SessionPage.visit_page()
      |> SessionPage.enter_credentials(email, password)

    {:ok, admin_user: admin_user, sessions: [session1 | other_sessions]}
  end

  def create_and_login_admin(%{session: session}) do
    %AdminUser{user: %User{email: email, password: password}} =
      admin_user =
      insert(:admin_user,
        name: "Initial User",
        role: "admin",
        user: build(:user, email: "initial@admin.com")
      )

    session =
      session
      |> SessionPage.visit_page()
      |> SessionPage.enter_credentials(email, password)

    {:ok, admin_user: admin_user, session: session}
  end

  def create_and_login_admin(session) do
    %AdminUser{user: %User{email: email, password: password}} = insert(:admin_user)

    session
    |> SessionPage.visit_page()
    |> SessionPage.enter_credentials(email, password)
  end

  def create_and_login_admin(%{session: session}, opts) do
    role = if opts[:role], do: opts[:role], else: :admin
    admin = insert(:admin_user, role: role)
    %AdminUser{user: %User{email: email, password: password}} = admin

    session
    |> SessionPage.visit_page()
    |> SessionPage.enter_credentials(email, password)

    {:ok, admin_user: admin, session: session}
  end

  def delay(session, time) do
    :timer.sleep(time)
    session
  end

  def select_search_record(session, form, field, query, id),
    do:
      session
      |> fill_in(text_field("record_search_#{form}_#{field}"), with: query)
      |> delay(300)
      |> click(css("[phx-value-record_id='#{id}']"))
end
