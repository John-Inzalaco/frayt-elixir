defmodule FraytElixirWeb.Admin.CreateMatchTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  use Bamboo.Test, shared: true
  alias FraytElixir.Accounts.{AdminUser, User}
  alias FraytElixir.Shipment.Match

  setup :create_and_login_admin
  import FraytElixir.Test.WebhookHelper

  setup do
    start_batch_webhook_sender(self())
  end

  feature "create a scheduled dash match; shows up in match log", %{
    session: session,
    admin_user: %AdminUser{user: %User{email: admin_email}}
  } do
    %{shipper: %{user: %{email: shipper_email}}} = insert(:credit_card)
    %{name: "Admin User", id: admin_id} = insert(:admin_user, role: :sales_rep)

    pickup_at = DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second)

    {:ok, pickup_date} =
      Timex.Format.DateTime.Formatters.Default.format(pickup_at, "{0M}/{0D}/{YYYY}")

    {:ok, pickup_time} =
      Timex.Format.DateTime.Formatters.Default.format(pickup_at, "{0h12}:{0m}{AM}")

    session =
      session
      |> Admin.visit_page("matches")
      |> click(css("i", text: "add_circle_outline"))
      |> assert_has(css("h3", text: "Create Match"))
      |> fill_in(text_field("search_shipper_shipper_email"), with: shipper_email)
      |> click(css(".search__submit"))
      |> fill_in(text_field("match_origin_address"),
        with: "4533 Ruebel Place, Cincinnati, Ohio 45211"
      )
      |> fill_in(text_field("match_pickup_notes"), with: "Some pickup notes")
      |> fill_in(text_field("match_delivery_notes"), with: "Some delivery notes")
      |> Admin.toggle_checkbox("[for='match_scheduled']")
      |> fill_in(text_field("match_pickup_at_date"), with: pickup_date)
      |> fill_in(text_field("match_pickup_at_time"), with: pickup_time)
      |> set_value(css("option[value='3']"), :selected)
      |> fill_in(text_field("match_destination_address"),
        with: "708 Walnut Street, Cincinnati"
      )
      |> Admin.toggle_checkbox("[for='match_dropoff_asap']")
      |> Admin.toggle_checkbox("[for='match_self_recipient']")
      |> fill_in(text_field("match_po"), with: "po12345")
      |> fill_in(text_field("match_weight"), with: "25")
      |> fill_in(text_field("match_length"), with: "4")
      |> fill_in(text_field("match_width"), with: "3")
      |> fill_in(text_field("match_height"), with: "2")
      |> fill_in(text_field("match_pieces"), with: "4")
      |> fill_in(text_field("match_description"), with: "Some cargo description")
      |> Admin.toggle_checkbox("[for='match_has_load_fee']")
      |> set_value(css("option[value='#{admin_id}']"), :selected)
      |> click(button("Create Match"))
      |> delay(1000)
      |> refute_has(css("h3", text: "Create Match"))

    match_id = session |> Wallaby.Browser.current_url() |> Path.basename()

    match = Repo.get!(Match, match_id)

    {:ok, pickup_display} =
      pickup_at
      |> DateTime.shift_zone!(match.timezone)
      |> Timex.Format.DateTime.Formatters.Default.format(
        "{0M}/{0D}/{YYYY} {0h12}:{0m}:00 {AM} {Zabbr}"
      )

    session
    |> assert_has(css("[data-test-id='admin-name']", text: "Admin User"))
    |> assert_has(
      css("[data-test-id='origin-address']", text: "4533 Ruebel Pl, Cincinnati, OH 45211, USA")
    )
    |> assert_has(
      css("[data-test-id='destination-address-0']",
        text: "708 Walnut Street 500, Cincinnati, Ohio 45202"
      )
    )
    |> click(css("[data-test-id='pickup-at']"))
    |> assert_has(css("[data-test-id='pickup-at']", text: pickup_display))
    |> click(css("[data-test-id='dropoff-at']"))
    |> assert_has(css("[data-test-id='dropoff-at']", text: "Now"))
    |> assert_has(css(".circle--checked", count: 2))
    |> assert_has(css(".circle--open", count: 5))
    |> assert_has(css("[data-test-id='pickup-notes']", text: "Some pickup notes"))
    |> assert_has(css("[data-test-id='delivery-notes-0']", text: "Some delivery notes"))
    |> assert_has(css("[data-test-id='po']", text: "po12345"))
    |> assert_has(css("[data-test-id='load-unload']", text: "Yes"))
    |> assert_has(css("[data-test-id='no-recipient-0']"))
    |> assert_has(css("[data-test-id='vehicle-class']", text: "Cargo Van"))
    |> assert_has(css("[data-test-id='service-level']", text: "Dash"))
    |> click(css("a", text: "View Match Log"))
    |> assert_has(css("td", text: "Created Match"))
    |> assert_has(css("td", text: "User: #{admin_email}", count: 11))
  end

  @tag :skip
  # TODO fix this test
  feature "displays proper errors and creates non-scheduled match", %{session: session} do
    %{shipper: %{user: %{email: shipper_email}}} = insert(:credit_card)

    session
    |> Admin.visit_page("matches/create")
    |> set_value(css("option[value='4']"), :selected)
    |> click(button("Create Match"))
    |> assert_has(css(".error", count: 8))
    |> set_value(css("option[value='3']"), :selected)
    |> set_value(css("#match_service_level option[value='2']"), :selected)
    |> fill_in(text_field("match_weight"), with: "25")
    |> fill_in(text_field("match_length"), with: "4")
    |> fill_in(text_field("match_width"), with: "3")
    |> fill_in(text_field("match_height"), with: "2")
    |> fill_in(text_field("match_pieces"), with: "4")
    |> fill_in(text_field("match_description"), with: "Some cargo description")
    |> fill_in(text_field("match_recipient_name"), with: "Some Recipient")
    |> fill_in(text_field("match_recipient_phone"), with: "456-654-3456")
    |> fill_in(text_field("match_recipient_email"), with: "some@recipient.com")
    |> fill_in(text_field("search_shipper_shipper_email"), with: shipper_email)
    |> fill_in(text_field("match_origin_address"),
      with: "4533 Ruebel Place, Cincinnati, Ohio 45211"
    )
    |> fill_in(text_field("match_destination_address"),
      with: "708 Walnut Street, Cincinnati"
    )
    |> click(button("Create Match"))
    |> delay(1000)
    |> assert_has(
      css("[data-test-id='origin-address']", text: "4533 Ruebel Pl, Cincinnati, OH 45211, USA")
    )
    |> assert_has(
      css("[data-test-id='destination-address']",
        text: "708 Walnut Street 500, Cincinnati, Ohio 45202"
      )
    )
    |> click(css("[data-test-id='item']"))
    |> assert_has(
      css("[data-test-id='item']",
        text: "4 Some cargo description @ 4\" x 3\" x 2\" and 25lbs each"
      )
    )
    |> assert_has(css("[data-test-id='load-unload']", text: "No"))
    |> assert_has(css("[data-test-id='vehicle-class']", text: "Cargo Van"))
    |> assert_has(css("[data-test-id='service-level']", text: "Same Day"))
    |> assert_has(css("[data-test-id='recipient-name-0']", text: "Some Recipient"))
    |> assert_has(css("[data-test-id='recipient-phone-0']", text: "(456)654-3456"))
    |> assert_has(css("[data-test-id='recipient-email-0']", text: "some@recipient.com"))
    |> assert_has(css(".circle--checked", count: 2))
    |> assert_has(css(".circle--open", count: 4))
  end

  @tag :skip
  # TODO fix this test
  feature "create a fully scheduled match", %{session: session} do
    %{shipper: %{user: %{email: shipper_email}}} = insert(:credit_card)
    %{code: coupon_code} = insert(:coupon)

    pickup_at = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 * 2 + 60 * 97)

    {:ok, pickup_date} =
      Timex.Format.DateTime.Formatters.Default.format(pickup_at, "{0M}/{0D}/{YYYY}")

    {:ok, pickup_time} =
      Timex.Format.DateTime.Formatters.Default.format(pickup_at, "{0h12}:{0m}{AM}")

    {:ok, pickup_time_display} =
      Timex.Format.DateTime.Formatters.Default.format(pickup_at, "{0h12}:{0m}:{0s} {AM}")

    dropoff_at = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 * 2 + 60 * 150)

    {:ok, dropoff_date} =
      Timex.Format.DateTime.Formatters.Default.format(dropoff_at, "{0M}/{0D}/{YYYY}")

    {:ok, dropoff_time} =
      Timex.Format.DateTime.Formatters.Default.format(dropoff_at, "{0h12}:{0m}{AM}")

    {:ok, dropoff_time_display} =
      Timex.Format.DateTime.Formatters.Default.format(dropoff_at, "{0h12}:{0m}:{0s} {AM}")

    session
    |> Admin.visit_page("matches/create")
    |> fill_in(text_field("search_shipper_shipper_email"), with: shipper_email)
    |> fill_in(text_field("match_origin_address"),
      with: "4533 Ruebel Place, Cincinnati, Ohio 45211"
    )
    |> Admin.toggle_checkbox("[for='match_scheduled']")
    |> fill_in(text_field("match_pickup_at_date"), with: pickup_date)
    |> fill_in(text_field("match_pickup_at_time"), with: pickup_time)
    |> set_value(css("option[value='3']"), :selected)
    |> fill_in(text_field("match_destination_address"),
      with: "708 Walnut Street, Cincinnati"
    )
    |> fill_in(text_field("match_dropoff_at_date"), with: dropoff_date)
    |> fill_in(text_field("match_dropoff_at_time"), with: dropoff_time)
    |> Admin.toggle_checkbox("[for='match_self_recipient']")
    |> fill_in(text_field("match_weight"), with: "25")
    |> fill_in(text_field("match_length"), with: "4")
    |> fill_in(text_field("match_width"), with: "3")
    |> fill_in(text_field("match_height"), with: "2")
    |> fill_in(text_field("match_pieces"), with: "4")
    |> fill_in(text_field("match_coupon"), with: coupon_code)
    |> click(button("Create Match"))
    |> assert_has(
      css("[data-test-id='origin-address']", text: "4533 Ruebel Pl, Cincinnati, OH 45211, USA")
    )
    |> assert_has(
      css("[data-test-id='destination-address']",
        text: "708 Walnut Street 500, Cincinnati, Ohio 45202"
      )
    )
    |> assert_has(
      css("[data-test-id='pickup-at']", text: "#{pickup_date} #{pickup_time_display}")
    )
    |> assert_has(
      css("[data-test-id='dropoff-at']", text: "#{dropoff_date} #{dropoff_time_display}")
    )
    |> assert_has(css("[data-test-id='coupon_description']", text: coupon_code))
  end

  feature "shows proper error if a shipper has no payments set up", %{session: session} do
    %{user: %{email: shipper_email}} = insert(:shipper)

    session
    |> Admin.visit_page("matches/create")
    |> set_value(css("option[value='3']"), :selected)
    |> set_value(css("#match_service_level option[value='1']"), :selected)
    |> fill_in(text_field("match_weight"), with: "25")
    |> fill_in(text_field("match_length"), with: "4")
    |> fill_in(text_field("match_width"), with: "3")
    |> fill_in(text_field("match_height"), with: "2")
    |> fill_in(text_field("match_pieces"), with: "4")
    |> fill_in(text_field("match_recipient_name"), with: "Some Recipient")
    |> fill_in(text_field("match_recipient_phone"), with: "513-402-3456")
    |> fill_in(text_field("match_recipient_email"), with: "some@recipient.com")
    |> fill_in(text_field("search_shipper_shipper_email"), with: shipper_email)
    |> fill_in(text_field("match_origin_address"),
      with: "4533 Ruebel Place, Cincinnati, Ohio 45211"
    )
    |> fill_in(text_field("match_destination_address"),
      with: "708 Walnut Street, Cincinnati"
    )
    |> click(button("Create Match"))
    |> assert_has(css(".error", text: "Payment is not set up"))
  end
end
