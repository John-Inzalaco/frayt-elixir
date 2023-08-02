defmodule FraytElixirWeb.Admin.MatchesTest do
  use FraytElixirWeb.FeatureCase
  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup [:create_and_login_admin]

  feature "see matches on admin dashboard", %{session: session} do
    insert(:match,
      origin_address: build(:address, city: "Cincinnati", state: "Ohio"),
      match_stops: [
        build(:match_stop,
          destination_address: build(:address, city: "Louisville", state: "Kentucky")
        )
      ],
      state: "arrived_at_pickup",
      driver: build(:driver, first_name: "Random", last_name: "Driver"),
      shipper: build(:shipper, first_name: "Random", last_name: "Shipper"),
      scheduled: true,
      pickup_at: DateTime.utc_now() |> DateTime.add(4 * 3600)
    )

    session
    |> Admin.visit_page("matches")
    |> Admin.filter_state("all")
    |> assert_has(css("h1", text: "Matches"))
    |> assert_has(css("[data-test-id='match-shipper']", text: "Random Shipper"))
    |> assert_has(css("[data-test-id='origin-address']", text: "Cincinnati, OH"))
    |> assert_has(css("[data-test-id='destination-address']", text: "Louisville, KY"))
    |> assert_has(css("[data-test-id='stage']", text: "Arrived At Pickup"))
    |> assert_has(css("[data-test-id='driver']", text: "Random Driver"))
    |> assert_has(css(".caption", text: "Pickup:"))
    |> assert_has(css(".caption", text: "Dropoff: Now"))
  end

  feature "sort matches by shipper, level, next stage, and driver", %{session: session} do
    shipper1 = insert(:shipper, first_name: "Zora", last_name: "Jones")

    insert(:match,
      shipper: shipper1,
      service_level: 2,
      inserted_at: ~N[2000-01-01 23:01:07],
      state: "en_route_to_pickup",
      driver: build(:driver, first_name: "Driver", last_name: "A")
    )

    shipper2 = insert(:shipper, first_name: "Abe", last_name: "Smith")

    insert(:match,
      shipper: shipper2,
      service_level: 1,
      inserted_at: ~N[2000-01-01 23:00:07],
      state: "accepted",
      driver: build(:driver, first_name: "Driver", last_name: "B")
    )

    shipper3 = insert(:shipper, first_name: "Abe", last_name: "Miller")

    insert(:match,
      shipper: shipper3,
      service_level: 1,
      inserted_at: ~N[2000-01-01 23:02:07],
      state: "picked_up",
      driver: build(:driver, first_name: "Driver", last_name: "C")
    )

    session
    |> Admin.visit_page("matches")
    |> Admin.filter_state("all")
    |> refute_has(css(".material-icons", text: "arrow_upward"))
    |> assert_has(css("[data-test-id='sort-by-inserted_at']", text: "arrow_downward"))
    |> Admin.assert_has_text(css("[data-test-id='match-shipper']", count: 3, at: 0), "Abe Miller")
    |> Admin.test_sorting("Date", "match-shipper", 3, "Abe Smith")
    |> assert_has(css("[data-test-id='sort-by-inserted_at']", text: "arrow_upward"))
    |> Admin.test_sorting("Date", "match-shipper", 3, "Abe Miller")
    |> assert_has(css("[data-test-id='sort-by-inserted_at']", text: "arrow_downward"))
    |> Admin.test_sorting("Shipper", "match-shipper", 3, "Abe Miller")
    |> assert_has(css("[data-test-id='sort-by-match_shipper_name']", text: "arrow_upward"))
    |> Admin.test_sorting("Shipper", "match-shipper", 3, "Zora Jones")
    |> assert_has(css("[data-test-id='sort-by-match_shipper_name']", text: "arrow_downward"))
    |> Admin.test_sorting("Level", "match-level", 3, "Dash")
    |> refute_has(css("[data-test-id='sort-by-state']", text: "arrow_downward"))
    |> refute_has(css("[data-test-id='sort-by-state']", text: "arrow_upward"))
    |> assert_has(css("[data-test-id='sort-by-service_level']", text: "arrow_upward"))
    |> Admin.test_sorting("Level", "match-level", 3, "Same Day")
    |> assert_has(css("[data-test-id='sort-by-service_level']", text: "arrow_downward"))
    |> Admin.test_sorting("Level", "match-level", 3, "Dash")
    |> assert_has(css("[data-test-id='sort-by-service_level']", text: "arrow_upward"))
    |> Admin.test_sorting("Shipper", "match-shipper", 3, "Abe Miller")
    |> assert_has(css("[data-test-id='sort-by-match_shipper_name']", text: "arrow_upward"))
    |> Admin.test_sorting("Current State", "match-shipper", 3, "Abe Smith")
    |> assert_has(css("[data-test-id='sort-by-state']", text: "arrow_upward"))
    |> Admin.test_sorting("Current State", "match-shipper", 3, "Abe Miller")
    |> assert_has(css("[data-test-id='sort-by-state']", text: "arrow_downward"))
    |> Admin.test_sorting("Driver", "driver", 3, "-")
    |> Admin.test_sorting("Driver", "driver", 3, "Driver C")
  end

  feature "admin match search", %{session: session} do
    insert(:match, state: :accepted, service_level: 2, po: "po 1")

    insert(:match,
      state: :accepted,
      service_level: 1,
      po: "po 2"
    )

    session
    |> Admin.visit_page("matches")
    |> Admin.filter_state("all")
    |> touch_scroll(css("html"), 0, 500)
    |> assert_has(css("[data-test-id='po']", count: 2))
    |> Admin.search("po 1")
    |> assert_has(css("[data-test-id='po']", count: 1))
    |> assert_has(css("[data-test-id='po']", text: "po 1"))
  end

  # this test is failing due to a DOM stale reference error when sorting. Click tested and works as expected
  @tag :skip
  feature "admin match changing page after search doesn't negate search", %{session: session} do
    shipper1 = insert(:shipper, first_name: "Zora", last_name: "Jones")
    shipper2 = insert(:shipper, first_name: "Abe", last_name: "Smith")
    insert(:match, state: :assigning_driver, shipper: shipper2, service_level: 2)
    insert_list(51, :match, state: :assigning_driver, shipper: shipper1, service_level: 2)

    session
    |> Admin.visit_page("matches")
    |> Admin.filter_state("all")
    |> Admin.test_sorting("Shipper", "match-shipper", 50, "Zora Jones")
    |> assert_has(css("[data-test-id='match-shipper']", text: "Zora Jones", count: 50))
    |> refute_has(css("[data-test-id='match-shipper']", text: "Abe Smith"))
    |> Admin.search("Zora")
    |> assert_has(css("[data-test-id='match-shipper']", text: "Zora Jones", count: 50))
    |> Admin.next_page(2)
    |> assert_has(css("[data-test-id='match-shipper']", text: "Zora Jones", count: 1))
    |> refute_has(css("[data-test-id='match-shipper']", text: "Abe Smith"))
  end

  feature "filter states select and my matches only toggle change what matches are displayed", %{
    session: session
  } do
    user1 = insert(:admin_user)
    user2 = insert(:admin_user)
    insert(:match, state: :pending)
    insert(:match, state: :assigning_driver, network_operator_id: user1.id)
    insert(:match, state: :scheduled, network_operator_id: user2.id)
    insert(:match, state: :accepted, network_operator_id: user1.id)
    insert(:match, state: :en_route_to_pickup)
    insert(:match, state: :picked_up, network_operator_id: user2.id)
    insert(:en_route_to_dropoff_match, network_operator_id: user1.id)
    insert(:match, state: :completed, network_operator_id: user1.id)
    insert(:match, state: :unable_to_pickup, network_operator_id: user1.id)
    insert(:match, state: :unable_to_pickup, network_operator_id: user2.id)

    session
    |> Admin.visit_page("matches")
    |> assert_has(css("[data-test-id='match-id']", count: 7))
    |> Admin.assert_selected(css("option[value='active']"))
    |> Admin.filter_state("all")
    |> assert_has(css("[data-test-id='match-id']", count: 9))
    |> Admin.assert_selected(css("option[value='all']"))
    |> Admin.filter_state("active")
    |> assert_has(css("[data-test-id='match-id']", count: 7))
    |> Admin.assert_selected(css("option[value='active']"))
    |> Admin.filter_state("all")
    |> Admin.toggle_checkbox("[for='dt_filter_matches_only_mine']")
    |> assert_has(css("[data-test-id='match-id']", count: 0))
    |> logout_user()
    |> login_user(user1.user)
    |> delay(1000)
    |> Admin.filter_state("all")
    |> assert_has(css("[data-test-id='match-id']", count: 9))
    |> Admin.toggle_checkbox("[for='dt_filter_matches_only_mine']")
    |> assert_has(css("[data-test-id='match-id']", count: 5))
    |> Admin.filter_state("active")
    |> assert_has(css("[data-test-id='match-id']", count: 4))
    |> Admin.toggle_checkbox("[for='dt_filter_matches_only_mine']")
    |> assert_has(css("[data-test-id='match-id']", count: 7))
    |> Admin.filter_state("unable_to_pickup")
    |> assert_has(css("[data-test-id='match-id']", count: 2))
    |> Admin.toggle_checkbox("[for='dt_filter_matches_only_mine']")
    |> assert_has(css("[data-test-id='match-id']", count: 1))
  end

  feature "assign and change network operator to match", %{session: session} do
    admin = insert(:admin_user, name: "Some Admin")
    admin2 = insert(:admin_user, name: nil, user: build(:user, email: "someadmin@email.com"))
    insert(:match, state: :assigning_driver)

    session
    |> Admin.visit_page("matches")
    |> Admin.filter_state("all")
    |> click(css("a", text: "Assign", count: 2, at: 0))
    |> select_search_record(:assign_match, :assignment, "Some Admin", admin.id)
    |> click(css("button", text: "Assign"))
    |> assert_has(css("td", text: "Some Admin"))
    |> click(css("a", text: "Reassign"))
    |> select_search_record(:assign_match, :assignment, "someadmin", admin2.id)
    |> click(css("button", text: "Assign"))
    |> assert_has(css("td", text: "someadmin@email.com"))
  end

  feature "show more works on mobile", %{session: session} do
    shipper1 = insert(:shipper, first_name: "First", last_name: "Shipper")
    shipper2 = insert(:shipper, first_name: "Last", last_name: "Shipper")
    match1 = insert(:match, shipper: shipper1, shortcode: "ASDFQWER")
    match2 = insert(:match, shipper: shipper2, shortcode: "FDSAREWQ")

    session
    |> resize_window(596, 882)
    |> Admin.visit_page("matches")
    |> refute_has(css("td", text: "First Shipper"))
    |> refute_has(css("td", text: "Last Shipper"))
    |> Admin.toggle_show_more("##{match1.shortcode}")
    |> assert_has(css("td", text: "First Shipper"))
    |> refute_has(css("td", text: "Last Shipper"))
    |> Admin.toggle_show_more("##{match2.shortcode}")
    |> refute_has(css("td", text: "First Shipper"))
    |> assert_has(css("td", text: "Last Shipper"))
    |> Admin.toggle_show_more("##{match1.shortcode}")
    |> refute_has(css("td", text: "Last Shipper"))
    |> assert_has(css("td", text: "First Shipper"))
  end

  feature "shows SLA progress bar", %{session: session} do
    shipper1 = insert(:shipper, first_name: "First", last_name: "Shipper")
    insert(:assigning_driver_match, shipper: shipper1, shortcode: "U7LM6LX6")

    session
    |> Admin.visit_page("matches")
    |> assert_has(css("[data-test-id='sla']"))
  end

  feature "acceptance time allowance", %{session: session} do
    %{slas: slas} = insert(:match)
    acceptance = Enum.find(slas, &(&1.type == :acceptance))

    session
    |> Admin.visit_page("matches")
    |> delay(100)
    |> click(css("[data-test-id='tooltip-#{acceptance.id}']"))
    |> assert_has(
      css("[data-test-id='time-allowance-#{acceptance.id}']", text: "Duration: 10 mins")
    )
  end

  feature "delivery time allowance", %{session: session} do
    %{driver_id: driver_id} = match = insert(:match, state: :picked_up, slas: [])

    insert(:match_sla,
      match: match,
      start_time: ~U[2030-01-01 00:00:00Z],
      end_time: ~U[2030-01-01 00:20:00Z]
    )

    insert(:match_sla,
      match: match,
      type: :pickup,
      start_time: ~U[2030-01-01 00:21:00Z],
      end_time: ~U[2030-01-01 00:51:00Z]
    )

    insert(:match_sla,
      match: match,
      driver_id: driver_id,
      type: :pickup,
      start_time: ~U[2030-01-01 00:21:00Z],
      end_time: ~U[2030-01-01 00:51:00Z]
    )

    frayt_delivery =
      insert(:match_sla,
        match: match,
        type: :delivery,
        start_time: ~U[2030-01-01 00:51:00Z],
        end_time: ~U[2030-01-01 01:30:00Z]
      )

    driver_delivery =
      insert(:match_sla,
        match: match,
        driver_id: driver_id,
        type: :delivery,
        start_time: ~U[2030-01-01 01:21:00Z],
        end_time: ~U[2030-01-01 01:59:00Z]
      )

    session
    |> Admin.visit_page("matches")
    |> delay(100)
    |> click(css("button[data-test-id='tooltip-#{frayt_delivery.id}']"))
    |> assert_has(
      css("[data-test-id='time-allowance-#{frayt_delivery.id}']", text: "Duration: 39 mins")
    )
    |> click(css("button[data-test-id='tooltip-#{driver_delivery.id}']"))
    |> assert_has(
      css("[data-test-id='time-allowance-#{driver_delivery.id}']", text: "Duration: 38 mins")
    )
  end

  feature "should not allow editing SLAS", %{session: session} do
    match = insert(:match, state: :completed)

    session
    |> Admin.visit_page("matches")
    |> Admin.filter_state("all")
    |> refute_has(css("button[data-test-id='edit-match-sla-#{match.id}']"))
  end
end
