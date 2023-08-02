defmodule FraytElixirWeb.Admin.MetricsDashboardTest do
  use FraytElixirWeb.FeatureCase
  use Bamboo.Test, shared: true

  import FraytElixirWeb.Test.FeatureTestHelper
  import FraytElixir.Test.StartMatchSupervisor

  alias FraytElixirWeb.Test.AdminTablePage, as: Admin

  setup :create_and_login_admin
  setup :start_match_supervisor

  feature "displays SLA metrics correctly", %{session: session} do
    [company1, company2, company3] = insert_list(3, :company, is_enterprise: true)

    location1 = insert(:location, company: company1)
    location2 = insert(:location, company: company2)
    location3 = insert(:location, company: company3)

    shipper1 = insert(:shipper, location: location1)
    shipper2 = insert(:shipper, location: location2)
    shipper3 = insert(:shipper, location: location3)

    first_day =
      DateTime.utc_now()
      |> Timex.beginning_of_month()

    one_day = 60 * 60 * 24

    insert_list(
      3,
      :match,
      shipper: shipper1,
      state: :completed,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: first_day,
          end_time: DateTime.add(first_day, 30 * 60, :second),
          completed_at: DateTime.add(first_day, 15 * 60, :second)
        )
      ]
    )

    insert_list(
      9,
      :match,
      shipper: shipper1,
      state: :completed,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: first_day,
          end_time: DateTime.add(first_day, 3 * 60, :second),
          completed_at: DateTime.add(first_day, 15 * 60, :second)
        )
      ]
    )

    insert_list(
      12,
      :match,
      shipper: shipper2,
      state: :canceled,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: DateTime.add(first_day, one_day, :second),
          end_time: DateTime.add(first_day, one_day, :second) |> DateTime.add(1 * 60, :second),
          completed_at: DateTime.add(first_day, one_day, :second) |> DateTime.add(3 * 60, :second)
        )
      ]
    )

    four_days = 4 * one_day

    insert_list(
      24,
      :match,
      shipper: shipper3,
      state: :charged,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: DateTime.add(first_day, four_days, :second),
          end_time: DateTime.add(first_day, four_days, :second) |> DateTime.add(12 * 60, :second),
          completed_at:
            DateTime.add(first_day, four_days, :second) |> DateTime.add(2 * 60, :second)
        )
      ]
    )

    insert(:metric_settings, sla_goal: 80)

    session
    |> Admin.visit_page("matches")
    |> click(css("[data-test-id='sla-range-month']"))
    |> assert_has(css("tr[data-test-id='sla-rating-for-All']"))
    |> assert_has(css("tr[data-test-id='sla-rating-for-All'] th:nth-of-type(3)", text: "56.25%"))
    |> assert_has(css("tr[data-test-id='sla-rating-for-#{company1.name}']"))
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company1.name}'] th:nth-of-type(2)", text: "80%")
    )
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company1.name}'] th:nth-of-type(3)", text: "25.0%")
    )
    |> assert_has(css("tr[data-test-id='sla-rating-for-#{company2.name}']"))
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company2.name}'] th:nth-of-type(3)", text: "0.0%")
    )
    |> assert_has(css("tr[data-test-id='sla-rating-for-#{company3.name}']"))
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company3.name}'] th:nth-of-type(3)", text: "100.0%")
    )
  end

  feature "filters SLA metrics correctly", %{session: session} do
    [company1, company2, company3] = insert_list(3, :company, is_enterprise: true)

    location1 = insert(:location, company: company1)
    location2 = insert(:location, company: company2)
    location3 = insert(:location, company: company3)

    shipper1 = insert(:shipper, location: location1)
    shipper2 = insert(:shipper, location: location2)
    shipper3 = insert(:shipper, location: location3)

    first_day =
      DateTime.utc_now()
      |> Timex.beginning_of_month()

    one_day = 60 * 60 * 24

    insert_list(
      3,
      :match,
      shipper: shipper1,
      state: :completed,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: first_day,
          end_time: DateTime.add(first_day, 30 * 60, :second),
          completed_at: DateTime.add(first_day, 15 * 60, :second)
        )
      ]
    )

    insert_list(
      9,
      :match,
      shipper: shipper1,
      state: :completed,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: first_day,
          end_time: DateTime.add(first_day, 3 * 60, :second),
          completed_at: DateTime.add(first_day, 15 * 60, :second)
        )
      ]
    )

    insert_list(
      12,
      :match,
      shipper: shipper2,
      state: :canceled,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: DateTime.add(first_day, one_day, :second),
          end_time: DateTime.add(first_day, one_day, :second) |> DateTime.add(1 * 60, :second),
          completed_at: DateTime.add(first_day, one_day, :second) |> DateTime.add(3 * 60, :second)
        )
      ]
    )

    four_days = 4 * one_day

    insert_list(
      24,
      :match,
      shipper: shipper3,
      state: :completed,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: DateTime.add(first_day, four_days, :second),
          end_time: DateTime.add(first_day, four_days, :second) |> DateTime.add(12 * 60, :second),
          completed_at:
            DateTime.add(first_day, four_days, :second) |> DateTime.add(2 * 60, :second)
        )
      ]
    )

    insert(:metric_settings, sla_goal: 80)

    session
    |> Admin.visit_page("matches")
    |> click(css("[data-test-id='sla-range-month']"))
    |> click(css("[data-test-id='edit-metric-filters-sla']"))
    |> set_value(css("select[data-test-id='filter-state'] option[value='completed']"), :selected)
    |> click(css("button[data-test-id='save-sla-filter']"))
    |> assert_has(css("tr[data-test-id^='sla-rating-for-']", count: 3))
    |> assert_has(css("tr[data-test-id='sla-rating-for-All'] th:nth-of-type(3)", text: "75.0%"))
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company1.name}'] th:nth-of-type(3)", text: "25.0%")
    )
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company3.name}'] th:nth-of-type(3)", text: "100.0%")
    )
    |> click(css("[data-test-id='edit-metric-filters-sla']"))
    |> set_value(css("select[data-test-id='filter-state'] option:first-child"), :selected)
    |> click(css("button[data-test-id='save-sla-filter']"))
    |> assert_has(css("tr[data-test-id^='sla-rating-for-']", count: 4))
  end

  feature "updates SLA goal successfully", %{session: session} do
    company = insert(:company, is_enterprise: true)
    location = insert(:location, company: company)
    shipper = insert(:shipper, location: location)
    now = DateTime.utc_now()

    insert_list(
      3,
      :match,
      shipper: shipper,
      state: :completed,
      slas: [
        build(
          :match_sla,
          type: :delivery,
          start_time: now,
          end_time: DateTime.add(now, 30 * 60, :second),
          completed_at: DateTime.add(now, 15 * 60, :second)
        )
      ]
    )

    session
    |> Admin.visit_page("matches")
    |> delay(100)
    |> click(css("[data-test-id='sla-range-month']"))
    |> click(css("[data-test-id='edit-metric-settings-sla']"))
    |> fill_in(text_field("metric_settings_form[sla_goal]"), with: "84")
    |> click(css("[data-test-id='save-sla-goal']"))
    |> assert_has(
      css("tr[data-test-id='sla-rating-for-#{company.name}'] th:nth-of-type(2)", text: "84%")
    )
  end
end
