defmodule FraytElixirWeb.Admin.MatchDetailsTest do
  use FraytElixirWeb.FeatureCase
  use Bamboo.Test, shared: true

  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Shipment.{MatchStopStateTransition, Match}
  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Accounts.{AdminUser, User}
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin
  import FraytElixirWeb.Test.FeatureTestHelper
  import FraytElixirWeb.Test.MatchPage
  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    start_batch_webhook_sender(self())
  end

  setup :create_and_login_admin
  setup :start_match_supervisor

  # may fail locally due to time zone differences -- assumes user system time is UTC
  feature "displays correct checks and timestamps on timeline", %{session: session} do
    match1 =
      insert(:match,
        state: :assigning_driver,
        scheduled: false,
        inserted_at: ~N[2014-10-02 00:19:12],
        driver: nil
      )

    match_state_transition_through_to(:assigning_driver, match1)

    %Match{match_stops: [stop2 | _]} =
      match2 =
      insert(:en_route_to_dropoff_match,
        scheduled: false,
        inserted_at: ~N[2014-10-02 00:19:12]
      )

    match_state_transition_through_to(:picked_up, match2)

    Repo.insert!(%MatchStopStateTransition{
      from: "pending",
      to: "en_route",
      match_stop: stop2,
      inserted_at: ~N[2014-10-02 00:43:12]
    })

    session
    |> Admin.visit_page("matches/#{match1.id}")
    |> assert_has(css(".circle--checked", count: 2))
    |> assert_has(css(".circle--open", count: 4))
    |> assert_has(css("[data-test-id='time-to-authorize']", text: "00:10:00"))
    |> assert_has(css("[data-test-id='authorized-time']", text: "Oct 2, 2014, 12:29:12 AM UTC"))
    |> assert_has(css(".circle--checked[data-test-id='started-check']"))
    |> assert_has(css(".circle--open[data-test-id='delivery-check']"))
    |> Admin.visit_page("matches/#{match2.id}")
    |> assert_has(css(".circle--checked", count: 4))
    |> assert_has(css(".circle--active", count: 1))
    |> assert_has(css(".circle--open", count: 1))
    |> assert_has(css("[data-test-id='time-to-authorize']", text: "00:01:00"))
    |> assert_has(css("[data-test-id='authorized-time']", text: "Oct 2, 2014, 12:20:12 AM UTC"))
    |> assert_has(css(".circle--checked[data-test-id='started-check']"))
    |> assert_has(css(".circle--open[data-test-id='delivery-check']"))
  end

  feature "force state change links work", %{session: session} do
    %PaymentTransaction{match: match} =
      insert(:payment_transaction,
        transaction_type: :authorize,
        status: "succeeded",
        match:
          build(:match,
            amount_charged: 2000,
            shortcode: "34ERF2F2",
            shipper: build(:shipper, user: build(:user, email: "some@shipper.com")),
            state: :accepted,
            match_stops: [
              build(:match_stop,
                recipient: insert(:contact, email: "recipient@email.com", name: "John Doe")
              )
            ],
            driver: build(:driver_with_wallet),
            inserted_at: ~N[2014-10-02 00:19:12]
          )
      )

    insert(:match_sla, type: :pickup, match: match, driver_id: match.driver_id)
    insert(:match_sla, type: :delivery, match: match, driver_id: match.driver_id)

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css(".circle--checked", count: 3))
    |> assert_has(css(".circle--open", count: 3))
    |> assert_has(css(".circle--checked[data-test-id='started-check']"))
    |> assert_has(css(".circle--open[data-test-id='delivery-check']"))
    |> click(css("[data-test-id='pickup-link']"))
    |> assert_has(css(".circle--checked", count: 4))
    |> assert_has(css(".circle--open", count: 2))

    assert_email_delivered_with(
      subject: "Picked Up – #{match.po}/#{match.shortcode}",
      to: [nil: "some@shipper.com"],
      bcc: [{"John Doe", "recipient@email.com"}, {nil, "notifications@frayt.com"}]
    )

    session
    |> click(css("[data-test-id='delivery-link']"))
    |> assert_has(css(".circle--checked", count: 6))
    |> refute_has(css(".circle--open"))

    assert_email_delivered_with(
      subject: "Completed – #{match.po}/#{match.shortcode}",
      to: [nil: "some@shipper.com"]
    )
  end

  feature "cancel match", %{session: session} do
    match =
      insert(:match,
        id: "f0cbe109-d12d-4190-b32f-b4d653938196",
        shortcode: "F0CBE109",
        state: :accepted,
        shipper: build(:shipper, user: build(:user, email: "shipper@email.com")),
        driver: build(:driver, user: build(:user, email: "driver@email.com"))
      )

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "Cancel Match"))
    |> click(button("Cancel Match"))
    |> assert_has(css("h3", text: "Match ##{match.shortcode} Canceled"))
    |> refute_has(css("b", text: "Reason Canceled:"))

    assert_email_delivered_with(
      subject: "Admin Canceled – #{match.po}/#{match.shortcode}",
      to: [nil: "shipper@email.com"]
    )

    assert_email_delivered_with(
      subject: "Admin Canceled – #{match.po}/#{match.shortcode}",
      to: [nil: "driver@email.com"]
    )
  end

  feature "cancel match with reason", %{session: session} do
    match =
      insert(:match,
        id: "f0cbe109-d12d-4190-b32f-b4d653938196",
        shortcode: "F0CBE109",
        state: :accepted,
        shipper: build(:shipper, user: build(:user, email: "shipper@email.com")),
        driver: build(:driver, user: build(:user, email: "driver@email.com"))
      )

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "Cancel Match"))
    |> fill_in(text_field("cancel_form[cancel_reason]"), with: "some random reason")
    |> click(button("Cancel Match"))
    |> assert_has(css("h3", text: "Match ##{match.shortcode} Canceled"))
    |> assert_has(css("b", text: "Reason Canceled:"))
    |> assert_has(css("p", text: "some random reason"))

    assert_email_delivered_with(
      subject: "Admin Canceled – #{match.po}/#{match.shortcode}",
      to: [nil: "shipper@email.com"]
    )

    assert_email_delivered_with(
      subject: "Admin Canceled – #{match.po}/#{match.shortcode}",
      to: [nil: "driver@email.com"]
    )
  end

  feature "Admin has option to add cancel charge while canceling match", %{session: session} do
    match =
      insert(:match,
        id: "f0cbe109-d12d-4190-b32f-b4d653938196",
        shortcode: "KC7EVL3R",
        amount_charged: 2000,
        state: :accepted,
        shipper: build(:shipper, user: build(:user, email: "shipper@email.com")),
        driver: build(:driver_with_wallet, user: build(:user, email: "driver@email.com"))
      )

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "Cancel Match"))
    |> assert_has(css("label", text: "Add Cancel Charge"))
    |> click(css("label", text: "Add Cancel Charge"))
    |> assert_has(css("[id='cancel_form_cancel_charge']"))
    |> fill_in(text_field("cancel_form_cancel_charge"), with: "60")
    |> fill_in(text_field("cancel_form_cancel_charge_driver_pay"), with: "50")
    |> click(button("Cancel Match"))
    |> click(css("[data-test-id='cancel_charge_amount']"))
    |> assert_has(css("[data-test-id='cancel_charge_amount']", text: "$12.00"))
    |> assert_has(css("[data-test-id='cancel_charge_driver_amount']", text: "$6.00"))
  end

  feature "admin can not add a cancel charge to a match without a driver", %{session: session} do
    match =
      insert(:match,
        id: "f0cbe109-d12d-4190-b32f-b4d653938196",
        shortcode: "KC7EVL3R",
        amount_charged: 2000,
        state: :assigning_driver,
        shipper: build(:shipper, user: build(:user, email: "shipper@email.com")),
        driver: nil
      )

    match_state_transition_through_to(:assigning_driver, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "Cancel Match"))
    |> refute_has(css("label", text: "Add Cancel Charge"))
  end

  feature "admin can add a cancel charge to an already canceled match", %{session: session} do
    match =
      insert(:match,
        id: "f0cbe109-d12d-4190-b32f-b4d653938196",
        shortcode: "KC7EVL3R",
        amount_charged: 2000,
        cancel_charge: nil,
        state: :accepted,
        shipper: build(:shipper, user: build(:user, email: "shipper@email.com")),
        driver: build(:driver_with_wallet, user: build(:user, email: "driver@email.com"))
      )

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "Cancel Match"))
    |> assert_has(css("label", text: "Add Cancel Charge"))
    |> click(button("Cancel Match"))
    |> click(css(".close-alert"))
    |> click(button("Add Cancel Charge"))
    |> fill_in(text_field("add_charge_form_cancel_charge"), with: "60")
    |> fill_in(text_field("add_charge_form_cancel_charge_driver_pay"), with: "50")
    |> assert_has(css("span", text: "They will be paid $6.00."))
    |> click(button("Add Cancel Charge", count: 2, at: 1))
    |> assert_has(css("[data-test-id='cancel_charge_amount']", text: "$12.00"))
    |> assert_has(css("[data-test-id='cancel_charge_driver_amount']", text: "$6.00"))
  end

  feature "admin can not add a cancel charge to an already canceled match without a driver", %{
    session: session
  } do
    match =
      insert(:match,
        id: "f0cbe109-d12d-4190-b32f-b4d653938196",
        shortcode: "KC7EVL3R",
        amount_charged: 2000,
        cancel_charge: nil,
        state: :admin_canceled,
        shipper: build(:shipper, user: build(:user, email: "shipper@email.com")),
        driver: nil
      )

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> refute_has(button("Add Cancel Charge"))
  end

  feature "can assign driver if none is assigned", %{session: session} do
    match = insert(:match, driver: nil, state: :assigning_driver)

    driver =
      insert(:driver_with_wallet,
        first_name: "New",
        last_name: "Driver",
        current_location: build(:driver_location, driver: nil)
      )

    driver_2 = insert(:driver_with_wallet, current_location: build(:driver_location, driver: nil))

    insert(:vehicle, driver: driver)
    insert(:vehicle, driver: driver_2)
    insert(:driver_location, driver: driver)
    insert(:driver_location, driver: driver_2)

    match_state_transition_through_to(:assigning_driver, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("h3", text: "Driver Search"))
    |> set_value(css("#dt_filter_capacity_driver_location option[value='address']"), :selected)
    |> click(button("Search"))
    |> click(css("[data-test-id='assign-driver']"))
    |> click(css("[data-test-id='assign-driver-#{driver.id}']"))
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("[data-test-id='driver-name']", text: "New Driver"))
    |> assert_has(css(".circle--checked", count: 3))
    |> assert_has(css("a", text: "Remove Driver"))
  end

  feature "can remove driver if one is assigned", %{session: session} do
    match =
      insert(:accepted_match,
        driver: build(:driver_with_wallet, first_name: "New", last_name: "Driver")
      )

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("[data-test-id='driver-name']", text: "New Driver"))
    |> click(css("a", text: "Remove Driver"))
    |> delay(500)
    |> assert_has(css("h3", text: "Driver Search"))
    |> assert_has(css(".circle--checked", count: 2))
    |> refute_has(css("[data-test-id='driver-name']", text: "New Driver"))
  end

  feature "cannot remove driver for match that has been delivered", %{session: session} do
    match =
      insert(:completed_match,
        driver: build(:driver_with_wallet, first_name: "New", last_name: "Driver")
      )

    match_state_transition_through_to(:completed, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> refute_has(css("a", text: "Remove Driver"))
  end

  feature "notify drivers about a match", %{session: session} do
    match =
      insert(:match,
        driver: nil,
        state: :assigning_driver,
        origin_address: build(:address, geo_location: chicago_point())
      )

    match_state_transition_through_to(:assigning_driver, match)

    driver =
      insert(:driver_with_wallet,
        current_location: build(:driver_location, geo_location: chicago_point(), driver: nil)
      )

    driver = set_driver_default_device(driver)

    insert(:vehicle, driver: driver)
    insert(:driver_location, geo_location: chicago_point(), driver: driver)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("button", text: "Send Push Notifications"))
    |> delay(1000)
    |> assert_has(css("p", text: "Drivers have been notified."))

    sent_notifications =
      from(sent in SentNotification, where: sent.driver_id == ^driver.id)
      |> Repo.all()

    assert Enum.count(sent_notifications) > 0
  end

  feature "assign and change network operator", %{session: session} do
    admin = insert(:admin_user, name: "Some Admin")
    admin2 = insert(:admin_user, name: nil, user: build(:user, email: "someadmin@email.com"))
    match = insert(:match, driver: nil)
    match_state_transition_through_to(:assigning_driver, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "Assign"))
    |> select_search_record(:assign_match, :assignment, "Some Admin", admin.id)
    |> click(css("button.button.button--primary[type=submit]", text: "Assign"))
    |> assert_has(css("[data-test-id='admin-name']", text: "Some Admin"))
    |> click(css("[data-test-id='reassign-admin']"))
    |> select_search_record(:assign_match, :assignment, "someadmin", admin2.id)
    |> click(css("button.button.button--primary[type=submit]", text: "Assign"))
    |> assert_has(css("[data-test-id='admin-name']", text: "someadmin@email.com"))
  end

  feature "timeline works when a scheduled match doesn't go through scheduled state", %{
    session: session
  } do
    match = insert(:match, state: :accepted, scheduled: true, shortcode: "K456L3K2")

    match_state_transition_through_to(:accepted, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("h3", text: "Match ##{match.shortcode}"))
  end

  @tag :skip
  feature "admin can assign a driver to a scheduled match", %{session: session} do
    tomorrow = DateTime.utc_now() |> DateTime.add(24 * 3600)
    match = insert(:match, state: :scheduled, scheduled: true, pickup_at: tomorrow, driver: nil)

    driver = insert(:driver_with_wallet, first_name: "New", last_name: "Driver")
    driver_2 = insert(:driver_with_wallet)
    insert(:vehicle, driver: driver)
    insert(:vehicle, driver: driver_2)
    insert(:driver_location, driver: driver)
    insert(:driver_location, driver: driver_2)
    match_state_transition_through_to(:scheduled, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("h3", text: "Driver Search"))
    |> click(css("[data-test-id='assign-driver']"))
    |> click(css("[data-test-id='assign-driver-#{driver.id}']"))
    |> assert_has(css("[data-test-id='driver-name']", text: "New Driver"))
    |> refute_has(css("h3", text: "Driver Search"))
    |> assert_has(css(".circle--checked", count: 3))
    |> assert_has(css("a", text: "Remove Driver"))
  end

  feature "admin can edit pickup on a match", %{session: session} do
    match = insert(:match, state: :scheduled, driver: nil)
    match_state_transition_through_to(:scheduled, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> edit_pickup(%{
      origin_address: "123 Main St, Cincinnati, OH 45202, USA"
    })
    |> assert_has(
      css("[data-test-id='origin-address']", text: "123 Main St, Cincinnati, OH 45202, USA")
    )
  end

  feature "admin can edit stop on a match", %{session: session} do
    %{match_stops: [stop]} = match = insert(:match, state: :scheduled, driver: nil)
    match_state_transition_through_to(:scheduled, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> edit_stop(stop.id, %{
      destination_address: "456 Main St, Cincinnati, OH 45202, USA"
    })
    |> assert_has(
      css("[data-test-id='destination-address-#{stop.index}']",
        text: "456 Main St, Cincinnati, OH 45202, USA"
      )
    )
  end

  @tag :skip
  # TODO fix this
  feature "admin can edit logistics on a match with a load fee", %{session: session} do
    match =
      insert(:match,
        state: :scheduled,
        match_stops: [
          build(:match_stop,
            items: [
              build(:match_stop_item, length: 10, width: 10, height: 10, weight: 100, pieces: 2)
            ]
          )
        ]
      )

    match_state_transition_through_to(:scheduled, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> edit_logistics(%{
      vehicle_class: "3",
      po: "SOME_NEW_PO"
    })
    |> assert_has(css("[data-test-id='vehicle-class']", text: "Cargo Van"))
    |> assert_has(css("[data-test-id='load-unload']", text: "Yes"))
    |> assert_has(css("[data-test-id='po']", text: "SOME_NEW_PO"))
  end

  # @tag timeout: 90_000
  # Not sure why this is failing... screenshot shows the correct thing
  @tag :skip
  feature "add notes to a match", %{session: session} do
    match = insert(:match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> refute_has(css("[data-test-id='save_notes']", text: "Save"))
    |> refute_has(css("[data-test-id='cancel_notes']", text: "Cancel"))
    |> click(css("textarea"))
    |> assert_has(css("[data-test-id='save_notes']", text: "Save"))
    |> assert_has(css("[data-test-id='cancel_notes']", text: "Cancel"))
    |> fill_in(text_field("match-notes"), with: "This is a note.")
    |> click(css("[data-test-id='save_notes']", text: "Save"))
    |> refute_has(css("[data-test-id='save_notes']", text: "Save"))
    |> refute_has(css("[data-test-id='cancel_notes']", text: "Cancel"))
    |> Admin.assert_textarea_text("This is a note.")
    |> fill_in(text_field("match-notes"), with: "This is another note.")
    |> click(css("[data-test-id='cancel_notes']", text: "Cancel"))
    |> refute_has(css("[data-test-id='save_notes']", text: "Save"))
    |> refute_has(css("[data-test-id='cancel_notes']", text: "Cancel"))
    |> Admin.assert_textarea_text("This is a note.")
    |> Admin.refute_textarea_text("This is another note.")
    |> fill_in(text_field("match-notes"), with: "")
    |> click(css("[data-test-id='save_notes']", text: "Save"))
    |> refute_has(css("[data-test-id='save_notes']", text: "Save"))
    |> refute_has(css("[data-test-id='cancel_notes']", text: "Cancel"))
    |> Admin.refute_textarea_text("This is a note.")
  end

  feature "admin can edit fees on a match", %{session: session} do
    %{shipper: shipper} = insert(:credit_card)

    match =
      insert(:match,
        state: :en_route_to_pickup,
        fees: [
          build(:match_fee, type: :base_fee, amount: 3000, driver_amount: 1500),
          build(:match_fee, type: :load_fee, amount: 1500, driver_amount: 1275)
        ],
        match_stops: [
          build(:match_stop,
            has_load_fee: true,
            items: [build(:match_stop_item, weight: 500)]
          )
        ],
        shipper: shipper
      )

    match_state_transition_through_to(:en_route_to_pickup, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> edit_fee(:base_fee, %{amount: 40, driver_amount: 30})
    |> assert_has(css("[data-test-id='base_fee_amount']", text: "$40.00"))
    |> assert_has(css("[data-test-id='base_fee_driver_amount']", text: "$30.00"))
    |> assert_has(css("[data-test-id='load_fee_amount']", text: "$15.00"))
    |> assert_has(css("[data-test-id='load_fee_driver_amount']", text: "$12.75"))
    |> assert_has(css("[data-test-id='driver_fees']", text: "$1.90"))
    |> assert_has(css("[data-test-id='amount_charged']", text: "$55.00"))
  end

  feature "admin can see driver tip on match detail screen", %{session: session} do
    match =
      insert(:match,
        state: :en_route_to_pickup,
        fees: [
          build(:match_fee, type: :driver_tip, amount: 2500, driver_amount: 2500)
        ],
        match_stops: [
          build(:match_stop,
            has_load_fee: false,
            items: [build(:match_stop_item, weight: 500)]
          )
        ]
      )

    match_state_transition_through_to(:en_route_to_pickup, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("[data-test-id='driver_tip_driver_amount']", text: "$25.00"))
  end

  @tag :skip
  # TODO fix this
  feature "cargo section shows items and not dimensions, weight, pieces, or description if match stop items are present",
          %{session: session} do
    match =
      insert(:match,
        state: :en_route_to_pickup,
        match_stops: [
          build(:match_stop,
            has_load_fee: false,
            items: [
              build(:match_stop_item,
                weight: 500
              )
            ]
          )
        ]
      )

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("[data-test-id='item']", count: 1))
    |> refute_has(css("[data-test-id='weight']"))
    |> refute_has(css("[data-test-id='dimensions']"))
    |> refute_has(css("[data-test-id='pieces']"))
    |> refute_has(css("[data-test-id='description']"))
  end

  feature "loads even if match state transitions are missing", %{session: session} do
    match =
      insert(:match,
        state: "completed",
        id: "1776b9f9-e0a7-4a1d-b8b9-6263423bfa44",
        shortcode: "1776B9F9"
      )

    match_state_transition_through_to(:completed, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("h3", text: "Match ##{match.shortcode}"))
  end

  feature "payment transaction history works", %{session: session} do
    match = insert(:match, driver: nil)

    insert(:payment_transaction,
      status: "succeeded",
      transaction_type: "authorize",
      amount: 5400,
      match: match
    )

    insert(:payment_transaction,
      status: "failed",
      transaction_type: "capture",
      amount: 5400,
      match: match
    )

    insert(:payment_transaction,
      status: "succeeded",
      transaction_type: "capture",
      amount: 5400,
      match: match
    )

    insert(:driver_bonus,
      notes: "Some bonus notes",
      payment_transaction:
        build(:payment_transaction,
          status: "succeeded",
          transaction_type: "transfer",
          amount: 1200,
          match: match
        )
    )

    insert(:payment_transaction,
      status: "succeeded",
      transaction_type: "transfer",
      amount: 3400,
      match: match
    )

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a", text: "View Payment Transactions"))
    |> assert_has(css("[data-phx-view='AdminMatchTransactions'] tbody tr", count: 5))
    |> click(css("tr", text: "12.00"))
    |> assert_has(css("[data-test-id='bonus-notes']", text: "Some bonus notes"))
    |> click(css(".material-icons", text: "cancel"))
    |> assert_has(css("[data-test-id='total-charged']", text: "$54.00"))
    |> assert_has(css("[data-test-id='driver-paid']", text: "$46.00"))
  end

  feature "match with vehicle class of 0 searches for all drivers", %{session: session} do
    %{id: match_id} = insert(:match, driver: nil, state: :assigning_driver, vehicle_class: 0)

    insert(:driver,
      first_name: "Driver",
      last_name: "One",
      vehicles: [build(:vehicle, vehicle_class: 1)]
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Two",
      vehicles: [build(:vehicle, vehicle_class: 2)]
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Three",
      vehicles: [build(:vehicle, vehicle_class: 3)]
    )

    insert(:driver,
      first_name: "Driver",
      last_name: "Four",
      vehicles: [build(:vehicle, vehicle_class: 4)]
    )

    session =
      session
      |> Admin.visit_page("matches/#{match_id}")
      |> click(css("a", text: "Assign Driver"))
      |> set_value(css("option[value='address']"), :selected)
      |> click(button("Search"))

    :timer.sleep(200)

    session
    |> Admin.visit_page("matches/#{match_id}")
    |> click(css("a", text: "Assign Driver"))
    |> delay(200)
    |> set_value(css("option[value='address']"), :selected)
    |> click(button("Search"))
    |> delay(500)
    |> assert_has(css("p", text: "Driver One"))
    |> assert_has(css("p", text: "Driver Two"))
    |> assert_has(css("p", text: "Driver Three"))
    |> assert_has(css("p", text: "Driver Four"))
  end

  feature "assign driver by email", %{session: session} do
    %{id: match_id} =
      match = insert(:match, state: :assigning_driver, driver: nil, vehicle_class: 3)

    %{user: %{email: driver_email}, id: driver_id} =
      insert(:driver_with_wallet,
        address: nil,
        first_name: "New",
        last_name: "Driver",
        user: build(:user)
      )

    insert_list(12, :driver_with_wallet, first_name: "Has", last_name: "Address")
    match_state_transition_through_to(:assigning_driver, match)

    session
    |> Admin.visit_page("matches/#{match_id}")
    |> assert_has(css("h3", text: "Driver Search"))
    |> assert_has(css(".driver__vehicle-details", count: 0))
    |> click(css("[data-test-id='assign-driver']"))
    |> fill_in(text_field("dt_filter_capacity_query"), with: driver_email)
    |> set_value(css("option[value='address']"), :selected)
    |> click(button("Search"))
    |> assert_has(css(".driver__vehicle-details", count: 1))
    |> click(css("[data-test-id='assign-driver-#{driver_id}']"))
    |> Admin.visit_page("matches/#{match_id}")
    |> assert_has(css("[data-test-id='driver-name']", text: "New Driver"))
    |> assert_has(css(".circle--checked", count: 3))
    |> assert_has(css("a", text: "Remove Driver"))
  end

  feature "displays correctly for shipperless match", %{session: session} do
    %{id: id, shortcode: shortcode} =
      match =
      insert(:match, shortcode: "1234ASDF", shipper: nil, driver: nil, state: :assigning_driver)

    match_state_transition_through_to(:en_route_to_pickup, match)

    session
    |> Admin.visit_page("matches/#{id}")
    |> assert_has(css("h3", text: "Match ##{shortcode}"))
  end

  feature "searches for all possible vehicle types", %{session: session} do
    %{id: driver1} =
      insert(:driver,
        vehicles: [build(:vehicle, vehicle_class: 3)]
      )

    %{id: driver2} =
      insert(:driver,
        vehicles: [build(:vehicle, vehicle_class: 4)]
      )

    %{id: driver3} =
      insert(:driver,
        vehicles: [build(:vehicle, vehicle_class: 2)]
      )

    %{id: match_id} = insert(:match, vehicle_class: 3, driver: nil)

    session
    |> Admin.visit_page("matches/#{match_id}")
    |> click(css("a", text: "Assign Driver"))
    |> set_value(css("option[value='address']"), :selected)
    |> click(button("Search"))
    |> assert_has(css("[data-test-id='assign-driver-#{driver1}']"))
    |> assert_has(css("[data-test-id='assign-driver-#{driver2}']"))
    |> refute_has(css("[data-test-id='assign-driver-#{driver3}']"))
  end

  feature "admin can activate a scheduled match", %{session: session} do
    %{id: match_id} =
      match =
      insert(:match,
        state: :scheduled,
        scheduled: true,
        pickup_at: DateTime.utc_now() |> DateTime.add(3600 * 48),
        driver: nil
      )

    match_state_transition_through_to(:scheduled, match)

    session
    |> Admin.visit_page("matches/#{match_id}")
    |> assert_has(css(".circle--checked", count: 2))
    |> assert_has(css(".circle--open", count: 5))
    |> click(css("a", text: "Activate Match"))
    |> delay(500)
    |> assert_has(css(".circle--checked", count: 3))
    |> assert_has(css(".circle--open", count: 4))
    |> refute_has(css("a", text: "Activate Match"))
  end

  feature "admin can activate an inactive match", %{session: session} do
    shipper = insert(:shipper_with_location)

    %{id: match_id} =
      insert(:match,
        state: :inactive,
        scheduled: true,
        fees: [
          build(:match_fee, type: :base_fee, amount: 1799, driver_amount: 1299)
        ],
        pickup_at:
          DateTime.utc_now()
          |> DateTime.add(3600 * 24 * 7)
          |> Timex.beginning_of_week(:mon)
          |> Timex.set(hour: 12, minute: 30),
        driver: nil,
        shipper: shipper,
        timezone: "UTC"
      )

    session
    |> Admin.visit_page("matches/#{match_id}")
    |> assert_has(css(".circle--checked", count: 1))
    |> assert_has(css(".circle--open", count: 6))
    |> click(css("a", text: "Authorize Match"))
    |> assert_has(css(".circle--checked", count: 2))
    |> assert_has(css(".circle--open", count: 5))
    |> refute_has(css("a", text: "Authorize Match"))
  end

  feature "match log works", %{session: session} do
    now = DateTime.utc_now()
    match1 = insert(:match, state: :admin_canceled)
    driver = insert(:driver)
    match2 = insert(:match)
    match_state_transition_through_to(:picked_up, match2)

    match_state_transition_through_to(:en_route_to_pickup, match1)

    insert(:hidden_match,
      match: match2,
      driver: driver,
      type: "driver_cancellation",
      reason: "Something came up",
      inserted_at: DateTime.add(now, 3600 * 2)
    )

    insert(:hidden_match,
      match: match1,
      driver: driver,
      type: "driver_cancellation",
      reason: "Something came up",
      inserted_at: DateTime.add(now, 3600 * 2)
    )

    insert(:match_state_transition,
      from: :en_route_to_pickup,
      to: :driver_canceled,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 2 + 60)
    )

    insert(:match_state_transition,
      from: :driver_canceled,
      to: :assigning_driver,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 2 + 65)
    )

    insert(:match_state_transition,
      from: :assigning_driver,
      to: :accepted,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 2 + 90)
    )

    insert(:hidden_match,
      match: match1,
      driver: driver,
      type: "driver_cancellation",
      reason: "Something else came up",
      inserted_at: DateTime.add(now, 3600 * 3)
    )

    insert(:match_state_transition,
      from: :accepted,
      to: :driver_canceled,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 3 + 60)
    )

    insert(:match_state_transition,
      from: :driver_canceled,
      to: :assigning_driver,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 3 + 65)
    )

    insert(:match_state_transition,
      from: :assigning_driver,
      to: :accepted,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 3 + 90)
    )

    insert(:match_state_transition,
      from: :accepted,
      to: :admin_canceled,
      match: match1,
      inserted_at: DateTime.add(now, 3600 * 4)
    )

    session
    |> Admin.visit_page("matches/#{match1.id}")
    |> click(css("a", text: "View Match Log"))
    |> assert_has(css("tr", count: 27))
    |> assert_has(css("tr", text: "State Change", count: 11))
    |> assert_has(css("tr", text: "Driver Cancellation", count: 2))
  end

  @tag :skip
  feature "match audit history displays on match log", %{
    session: session,
    admin_user: %AdminUser{user: %User{email: admin_email}}
  } do
    match = insert(:match, state: :scheduled, match_stops: [build(:match_stop)])
    match_state_transition_through_to(:scheduled, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> edit_logistics(%{
      vehicle_class: "3",
      po: "SOME_NEW_PO"
    })
    |> click(css("a", text: "View Match Log"))
    |> assert_has(css("td", text: "Updated Match", count: 2))
    |> delay(500)
    |> assert_has(css("td", text: "User: #{admin_email}", count: 2))
    |> click(css("label", text: "See changes", count: 6, at: 5))
    |> assert_has(css("b", text: "Weight"))
    |> assert_has(css("p", text: "400", count: 2))
  end

  feature "show warning msg when driver doesn't meet loading criteria", %{session: session} do
    match = insert(:match, driver: nil, state: :assigning_driver, unload_method: "lift_gate")

    driver =
      insert(:driver_with_wallet,
        first_name: "New Driver",
        last_name: "without lift_gate or pallet_jack",
        current_location: build(:driver_location, driver: nil)
      )

    driver_2 = insert(:driver_with_wallet, current_location: build(:driver_location, driver: nil))

    insert(:vehicle, driver: driver)
    insert(:vehicle, driver: driver_2)
    insert(:driver_location, driver: driver)
    insert(:driver_location, driver: driver_2)

    match_state_transition_through_to(:assigning_driver, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("h3", text: "Driver Search"))
    |> set_value(css("#dt_filter_capacity_driver_location option[value='address']"), :selected)
    |> click(button("Search"))
    |> assert_has(
      css("[data-test-id='assign-driver-warning-msg']",
        text: "Warning! This driver doesn't meet the required lift gate or pallet jack.",
        count: 2
      )
    )
  end

  feature "display vehicle tag for has_lift_gate and has_pallet_gate ", %{session: session} do
    match = insert(:match, driver: nil, state: :assigning_driver, unload_method: "lift_gate")

    driver =
      insert(:driver_with_wallet,
        first_name: "New",
        last_name: "Driver",
        current_location: build(:driver_location, driver: nil)
      )

    insert(:vehicle, driver: driver, lift_gate: true, pallet_jack: true)
    insert(:driver_location, driver: driver)

    match_state_transition_through_to(:assigning_driver, match)

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> assert_has(css("h3", text: "Driver Search"))
    |> set_value(css("option[value='address']"), :selected)
    |> click(button("Search"))
    |> assert_has(css("[data-test-id='lift-gate']", text: "Lift Gate"))
    |> assert_has(css("[data-test-id='pallet-jack']", text: "Pallet Jack"))
  end

  feature "display signature type and instructions", %{session: session} do
    match = insert(:match, driver: nil, state: :assigning_driver)
    sign_type_sel = "select[data-test-id=signature-type-input]"

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a[data-test-id='add-stop']"))
    |> assert_has(css("#{sign_type_sel} option[value=electronic][selected]"))
    |> assert_has(css("textarea[data-test-id=signature-instructions-input]"))
  end

  feature "signature type and instructions are saved successfully when create stop",
          %{session: session} do
    match =
      insert(
        :match,
        driver: nil,
        state: :assigning_driver,
        match_stops: [build(:match_stop, index: 0)]
      )

    # css selectors
    sign_type = "select[data-test-id=signature-type-input]"
    sign_instructions = "match_stop[signature_instructions]"

    # Form values
    address_text = "8200 Vineland Ave, Orlando, FL 32821, USA"
    delivery_notes = "delivery notes test"
    sign_instructions_text = "These are the instructions to write the signature"

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> click(css("a[data-test-id='add-stop']"))
    |> fill_in(text_field("match_stop[destination_address]"), with: address_text)
    |> fill_in(text_field("match_stop[delivery_notes]"), with: delivery_notes)
    |> fill_in(text_field("match_stop[po]"), with: "123456")
    |> set_value(css("#{sign_type} option[value=photo]"), :selected)
    |> fill_in(text_field(sign_instructions), with: sign_instructions_text)
    |> click(css("a[data-test-id='add-stop-item']"))
    |> fill_in(text_field("match_stop[items][0][description]"), with: "item 1")
    |> fill_in(text_field("match_stop[items][0][declared_value]"), with: 100)
    |> fill_in(text_field("match_stop[items][0][pieces]"), with: 10)
    |> fill_in(text_field("match_stop[items][0][weight]"), with: 5)
    |> fill_in(text_field("match_stop[items][0][volume]"), with: 29)
    |> fill_in(text_field("match_stop[items][0][width]"), with: 12)
    |> fill_in(text_field("match_stop[items][0][length]"), with: 11)
    |> fill_in(text_field("match_stop[items][0][height]"), with: 10)
    |> click(button("Create Stop"))
    |> delay(1000)
    |> assert_has(css(".match-stop", count: 2))
    |> assert_has(
      css(".match-stop:last-child p[data-test-id^='signature-type-name']", text: "Photo")
    )
    |> assert_has(
      css(".match-stop:last-child p[data-test-id^='signature-instructions']",
        text: sign_instructions_text
      )
    )
  end

  feature "should allow editing SLAS", %{session: session} do
    %{slas: slas} = match = insert(:match, state: :assigning_driver, driver: nil)
    match_state_transition_through_to(:assigning_driver, match)

    accept_sla = Enum.find(slas, &(&1.type == :acceptance))

    session
    |> Admin.visit_page("matches/#{match.id}")
    |> delay(100)
    |> click(css("button[data-test-id='edit-match-sla-#{match.id}']"))
    |> assert_has(css("label[for='#{accept_sla.id}-start_time']"))
    |> assert_has(css("[data-test-id='acceptance-sla-label']", text: "Acceptance"))
  end

  feature "should update sla start and end time", %{session: session} do
    %{driver_id: driver_id} = match = insert(:match, state: :accepted, slas: [])
    match_state_transition_through_to(:accepted, match)
    accept_sla = insert(:match_sla, match: match, type: :acceptance)
    insert(:match_sla, match: match, type: :pickup)
    insert(:match_sla, match: match, type: :pickup, driver_id: driver_id)
    insert(:match_sla, match: match, type: :delivery)
    insert(:match_sla, match: match, type: :delivery, driver_id: driver_id)

    matches_list =
      session
      |> Admin.visit_page("matches/#{match.id}")
      |> delay(100)
      |> click(css("button[data-test-id='edit-match-sla-#{match.id}']"))

    matches_list
    |> click(css("label[for='#{accept_sla.id}-start_time']"))
    |> find(css(".daterangepicker.single"))
    |> set_value(css("select.hourselect option[value='12']"), :selected)
    |> set_value(css("select.minuteselect option[value='0']"), :selected)
    |> set_value(css("select.ampmselect option[value='AM']"), :selected)
    |> click(css(".calendar-table table tbody td.today"))
    |> click(button("Apply"))

    matches_list
    |> click(css("button[data-test-id='update-sla-#{accept_sla.id}-start_time']"))

    updated = FraytElixir.Repo.get!(FraytElixir.SLAs.MatchSLA, accept_sla.id)

    assert DateTime.compare(updated.start_time, accept_sla.start_time) == :lt
    assert DateTime.compare(updated.end_time, accept_sla.end_time) == :eq
  end
end
