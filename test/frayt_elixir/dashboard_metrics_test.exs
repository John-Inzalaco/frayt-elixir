defmodule FraytElixir.DashboardMetricsTest do
  use FraytElixir.DataCase
  import FraytElixir.Factory
  import FraytElixir.DashboardMetrics
  alias FraytElixir.Cache

  describe "last_month/1" do
    test "gets previous month" do
      assert %{month: 12, year: 2019} = last_month(~D[2020-01-01])
      assert %{month: 11, year: 2021} = last_month(~D[2021-12-01])
    end
  end

  describe "get_metric_value" do
    test "gets cached values" do
      Cache.delete_all()

      %{user: %{email: email1}} =
        rep1 = insert(:admin_user, disabled: false, name: "A", role: :sales_rep, sales_goal: 2300)

      %{user: %{email: email2}} =
        rep2 = insert(:admin_user, disabled: false, name: "B", role: :sales_rep, sales_goal: 4250)

      %{user: %{email: email3}} =
        insert(:admin_user, disabled: false, name: "C", role: :sales_rep, sales_goal: 500_00)

      %{user: %{email: email4}} =
        insert(:admin_user, disabled: false, name: "D", role: :sales_rep, sales_goal: 0)

      %{user: %{email: email5}} =
        insert(:admin_user,
          disabled: false,
          name: nil,
          role: :sales_rep,
          sales_goal: nil,
          user: build(:user, email: "email@email.com")
        )

      insert(:admin_user, role: :sales_rep, disabled: true)
      insert(:admin_user, role: :admin)

      shipper1 = insert(:shipper, sales_rep: rep1)
      [shipper2, shipper3, shipper4, shipper5, shipper6, shipper7] = insert_list(6, :shipper)

      location1 = insert(:location, sales_rep: rep2, shippers: [shipper2, shipper3])
      location2 = insert(:location, shippers: [shipper4, shipper5, shipper6])

      insert(:company, locations: [location1], sales_rep: rep2)
      insert(:company, locations: [location2], sales_rep: rep1)

      [match1, match2, match3] =
        insert_list(3, :match,
          shipper: shipper1,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match1
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match1
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match2
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match3
      )

      insert(:match_state_transition,
        to: :charged,
        inserted_at: ~N[2021-01-23 12:32:04],
        match: match3
      )

      match4 =
        insert(:match,
          shipper: shipper1,
          amount_charged: 1000,
          state: :assigning_driver,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match4
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match4
      )

      match5 =
        insert(:match,
          shipper: shipper2,
          amount_charged: 1000,
          state: :completed,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match5
      )

      match6 =
        insert(:match,
          shipper: shipper3,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2021-01-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match6
      )

      insert(:match_state_transition,
        to: :charged,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match6
      )

      match7 =
        insert(:match,
          shipper: shipper4,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match7
      )

      match8 =
        insert(:match,
          shipper: shipper5,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match8
      )

      match9 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match9
      )

      match10 =
        insert(:match,
          shipper: shipper7,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match10
      )

      match11 =
        insert(:match,
          shipper: shipper1,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-24 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-24 12:30:04],
        match: match11
      )

      match12 =
        insert(:match,
          shipper: shipper4,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match12
      )

      match13 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-27 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-27 12:30:04],
        match: match13
      )

      match14 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-11-23 12:30:04],
        match: match14
      )

      match15 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-11-27 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-11-27 12:30:04],
        match: match15
      )

      assert [
               %{
                 name: "A",
                 email: ^email1,
                 goal: 2300,
                 sales: 9000,
                 rank: 1
               },
               %{
                 name: "B",
                 email: ^email2,
                 goal: 4250,
                 sales: 2000,
                 rank: 2
               },
               %{
                 name: nil,
                 email: ^email5,
                 goal: 0,
                 sales: 0,
                 rank: 3
               },
               %{
                 name: "D",
                 email: ^email4,
                 goal: 0,
                 sales: 0,
                 rank: 4
               },
               %{
                 name: "C",
                 email: ^email3,
                 goal: 50_000,
                 sales: 0,
                 rank: 5
               }
             ] = get_metric_value(:admin_metric_sales_goals_current, ~N[2020-12-23 15:32:32])

      assert {:ok,
              [
                %{
                  name: "A",
                  email: ^email1,
                  goal: 2300,
                  sales: 9000
                },
                %{
                  name: "B",
                  email: ^email2,
                  goal: 4250,
                  sales: 2000
                },
                %{
                  name: nil,
                  email: ^email5,
                  goal: 0,
                  sales: 0
                },
                %{
                  name: "D",
                  email: ^email4,
                  goal: 0,
                  sales: 0
                },
                %{
                  name: "C",
                  email: ^email3,
                  goal: 50_000,
                  sales: 0
                }
              ]} = get_cached_value(:admin_metric_sales_goals_current)

      assert [
               %{
                 name: "A",
                 email: ^email1,
                 goal: 2300,
                 sales: 9000
               },
               %{
                 name: "B",
                 email: ^email2,
                 goal: 4250,
                 sales: 2000
               },
               %{
                 name: nil,
                 email: ^email5,
                 goal: 0,
                 sales: 0
               },
               %{
                 name: "D",
                 email: ^email4,
                 goal: 0,
                 sales: 0
               },
               %{
                 name: "C",
                 email: ^email3,
                 goal: 50_000,
                 sales: 0
               }
             ] = get_metric_value(:admin_metric_sales_goals_current, ~N[2020-12-23 15:32:32])
    end

    test ":admin_metric_sales_goal" do
      %{user: %{email: email1}} =
        rep1 = insert(:admin_user, disabled: false, name: "A", role: :sales_rep, sales_goal: 2300)

      %{user: %{email: email2}} =
        rep2 = insert(:admin_user, disabled: false, name: "B", role: :sales_rep, sales_goal: 4250)

      %{user: %{email: email3}} =
        insert(:admin_user, disabled: false, name: "C", role: :sales_rep, sales_goal: 500_00)

      %{user: %{email: email4}} =
        insert(:admin_user, disabled: false, name: "D", role: :sales_rep, sales_goal: 0)

      %{user: %{email: email5}} =
        insert(:admin_user,
          disabled: false,
          name: nil,
          role: :sales_rep,
          sales_goal: nil,
          user: build(:user, email: "email@email.com")
        )

      insert(:admin_user, role: :sales_rep, disabled: true)
      insert(:admin_user, role: :admin)

      shipper1 = insert(:shipper, sales_rep: rep1)
      [shipper2, shipper3, shipper4, shipper5, shipper6, shipper7] = insert_list(6, :shipper)

      location1 = insert(:location, sales_rep: rep2, shippers: [shipper2, shipper3])
      location2 = insert(:location, shippers: [shipper4, shipper5, shipper6])

      insert(:company, locations: [location1], sales_rep: rep2)
      insert(:company, locations: [location2], sales_rep: rep1)

      [match1, match2, match3] =
        insert_list(3, :match,
          shipper: shipper1,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match1
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match1
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match2
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match3
      )

      insert(:match_state_transition,
        to: :charged,
        inserted_at: ~N[2021-01-23 12:32:04],
        match: match3
      )

      match4 =
        insert(:match,
          shipper: shipper1,
          amount_charged: 1000,
          state: :assigning_driver,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:32:04],
        match: match4
      )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match4
      )

      match5 =
        insert(:match,
          shipper: shipper2,
          amount_charged: 1000,
          state: :completed,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match5
      )

      match6 =
        insert(:match,
          shipper: shipper3,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2021-01-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match6
      )

      insert(:match_state_transition,
        to: :charged,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match6
      )

      match7 =
        insert(:match,
          shipper: shipper4,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match7
      )

      match8 =
        insert(:match,
          shipper: shipper5,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match8
      )

      match9 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match9
      )

      match10 =
        insert(:match,
          shipper: shipper7,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match10
      )

      match11 =
        insert(:match,
          shipper: shipper1,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-24 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-24 12:30:04],
        match: match11
      )

      match12 =
        insert(:match,
          shipper: shipper4,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-23 12:30:04],
        match: match12
      )

      match13 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-27 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-12-27 12:30:04],
        match: match13
      )

      match14 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-12-23 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-11-23 12:30:04],
        match: match14
      )

      match15 =
        insert(:match,
          shipper: shipper6,
          amount_charged: 1000,
          state: :charged,
          updated_at: ~N[2020-11-27 12:32:04]
        )

      insert(:match_state_transition,
        to: :completed,
        inserted_at: ~N[2020-11-27 12:30:04],
        match: match15
      )

      assert [
               %{
                 name: "A",
                 email: ^email1,
                 goal: 2300,
                 sales: 9000,
                 rank: 1,
                 progress: 391.30434782608694
               },
               %{
                 name: "B",
                 email: ^email2,
                 goal: 4250,
                 sales: 2000,
                 rank: 2,
                 progress: 47.05882352941176
               },
               %{
                 name: nil,
                 email: ^email5,
                 goal: 0,
                 sales: 0,
                 rank: 3,
                 progress: nil
               },
               %{
                 name: "D",
                 email: ^email4,
                 goal: 0,
                 sales: 0,
                 rank: 4,
                 progress: nil
               },
               %{
                 name: "C",
                 email: ^email3,
                 goal: 50_000,
                 sales: 0,
                 rank: 5,
                 progress: 0.0
               }
             ] =
               get_metric_value(:admin_metric_sales_goals_current, ~N[2020-12-23 15:32:32],
                 use_cache: false
               )
    end

    test ":admin_metric_monthly_revenue" do
      match1 = insert(:completed_match, amount_charged: 1500, cancel_charge: 500)

      insert(:match_state_transition,
        match: match1,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match1,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:30:43]
      )

      insert(:match_state_transition,
        match: match1,
        to: :canceled,
        inserted_at: ~N[2020-03-01 12:30:43]
      )

      match2 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :charged)

      insert(:match_state_transition,
        match: match2,
        to: :completed,
        inserted_at: ~N[2021-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match1,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      match3 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :assigning_driver)

      insert(:match_state_transition,
        match: match3,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      match4 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :canceled)

      insert(:match_state_transition,
        match: match4,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match4,
        to: :canceled,
        inserted_at: ~N[2020-03-01 12:33:43]
      )

      match5 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :admin_canceled)

      insert(:match_state_transition,
        match: match5,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match5,
        to: :admin_canceled,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      match6 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :charged)

      insert(:match_state_transition,
        match: match6,
        to: :completed,
        inserted_at: ~N[2020-04-01 12:32:43]
      )

      match5 = insert(:match, amount_charged: 1500, cancel_charge: nil, state: :admin_canceled)

      insert(:match_state_transition,
        match: match5,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match5,
        to: :admin_canceled,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      assert get_metric_value(:admin_metric_monthly_revenue, %{year: 2020, month: 3},
               use_cache: false
             ) == 2500
    end

    test ":admin_metric_last_month_revenue" do
      Cache.delete_all()
      match1 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :completed)

      insert(:match_state_transition,
        match: match1,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match1,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:30:43]
      )

      insert(:match_state_transition,
        match: match1,
        to: :canceled,
        inserted_at: ~N[2020-03-01 12:30:43]
      )

      match2 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :charged)

      insert(:match_state_transition,
        match: match2,
        to: :completed,
        inserted_at: ~N[2021-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match1,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      match3 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :assigning_driver)

      insert(:match_state_transition,
        match: match3,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      match4 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :canceled)

      insert(:match_state_transition,
        match: match4,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match4,
        to: :canceled,
        inserted_at: ~N[2020-03-01 12:33:43]
      )

      match5 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :admin_canceled)

      insert(:match_state_transition,
        match: match5,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match5,
        to: :admin_canceled,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      match6 = insert(:match, amount_charged: 1500, cancel_charge: 500, state: :charged)

      insert(:match_state_transition,
        match: match6,
        to: :completed,
        inserted_at: ~N[2020-04-01 12:32:43]
      )

      match5 = insert(:match, amount_charged: 1500, cancel_charge: nil, state: :admin_canceled)

      insert(:match_state_transition,
        match: match5,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      insert(:match_state_transition,
        match: match5,
        to: :admin_canceled,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      assert get_metric_value(:admin_metric_last_month_revenue, ~N[2020-04-01 00:00:00]) == 2500

      match7 = insert(:match, amount_charged: 1337, cancel_charge: nil, state: :charged)

      insert(:match_state_transition,
        match: match7,
        to: :completed,
        inserted_at: ~N[2020-03-01 12:32:43]
      )

      assert get_metric_value(:admin_metric_last_month_revenue, ~N[2020-04-01 00:00:00],
               use_cache: false
             ) == 3837
    end

    test ":admin_metric_monthly_new_shippers" do
      # Is this correct?
      insert_list(5, :shipper, state: "approved", inserted_at: ~N[2020-03-02 12:32:24])
      insert_list(5, :shipper, state: "disabled", inserted_at: ~N[2020-03-02 12:32:24])
      insert_list(5, :shipper, state: "approved", inserted_at: ~N[2021-03-02 12:32:24])
      insert_list(5, :shipper, state: "approved", inserted_at: ~N[2020-04-02 12:32:24])

      assert get_metric_value(:admin_metric_monthly_new_shippers, ~N[2020-03-02 12:32:24],
               use_cache: false
             ) == 5
    end

    test ":admin_metric_last_month_new_shippers" do
      Cache.delete_all()
      insert_list(5, :shipper, state: "disabled", inserted_at: ~N[2020-03-02 12:32:24])
      insert_list(5, :shipper, state: "approved", inserted_at: ~N[2020-03-02 12:32:24])
      insert_list(5, :shipper, state: "disabled", inserted_at: ~N[2021-03-02 12:32:24])
      insert_list(5, :shipper, state: "disabled", inserted_at: ~N[2020-04-02 12:32:24])

      assert get_metric_value(:admin_metric_last_month_new_shippers, ~N[2020-04-02 12:32:24]) == 5
    end

    test ":admin_metric_match_average_time" do
      now = ~N[2020-03-24 15:21:12]

      _match1 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 13:21:12],
          pickup_at: ~N[2020-03-24 10:21:12],
          state: :pending
        )

      match2 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 17:21:12],
          pickup_at: ~N[2020-03-24 14:21:12],
          state: :assigning_driver
        )

      match3 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 13:21:12],
          pickup_at: ~N[2020-03-24 10:21:12],
          state: :completed
        )

      match4 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 17:21:12],
          pickup_at: ~N[2020-03-24 14:21:12],
          state: :picked_up
        )

      match5 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 13:21:12],
          pickup_at: ~N[2020-03-24 10:21:12],
          state: :picked_up
        )

      match6 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 13:21:12],
          pickup_at: ~N[2020-03-24 10:21:12],
          state: :charged
        )

      _match7 =
        insert(:match,
          dropoff_at: ~N[2020-03-24 19:21:12],
          pickup_at: ~N[2020-03-24 16:21:12],
          state: :assigning_driver
        )

      insert(:match_state_transition,
        match: match2,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 10:23:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 13:21:12]
      )

      insert(:match_state_transition,
        match: match4,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match4,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 14:19:12]
      )

      insert(:match_state_transition,
        match: match5,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match5,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 10:21:12]
      )

      insert(:match_state_transition,
        match: match5,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 13:25:12]
      )

      insert(:match_state_transition,
        match: match6,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match6,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 10:22:12]
      )

      insert(:match_state_transition,
        match: match6,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 13:52:12]
      )

      assert get_metric_value(:admin_metric_match_average_time, now, use_cache: false) == 102
    end

    test ":admin_metric_match_average_time for dash scheduled" do
      now = ~N[2020-03-24 15:21:12]

      _match1 =
        insert(:match, dropoff_at: nil, pickup_at: ~N[2020-03-24 10:21:12], state: :pending)

      match2 =
        insert(:match,
          dropoff_at: nil,
          pickup_at: ~N[2020-03-24 14:21:12],
          state: :assigning_driver
        )

      match3 =
        insert(:match, dropoff_at: nil, pickup_at: ~N[2020-03-24 10:21:12], state: :completed)

      match4 =
        insert(:match, dropoff_at: nil, pickup_at: ~N[2020-03-24 14:21:12], state: :picked_up)

      match5 =
        insert(:match,
          dropoff_at: nil,
          pickup_at: ~N[2020-03-24 10:21:12],
          state: :picked_up
        )

      match6 =
        insert(:match, dropoff_at: nil, pickup_at: ~N[2020-03-24 10:21:12], state: :charged)

      _match7 =
        insert(:match,
          dropoff_at: nil,
          pickup_at: ~N[2020-03-24 16:21:12],
          state: :assigning_driver
        )

      insert(:match_state_transition,
        match: match2,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 10:23:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 11:21:12]
      )

      insert(:match_state_transition,
        match: match4,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match4,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 14:19:12]
      )

      insert(:match_state_transition,
        match: match5,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match5,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 10:21:12]
      )

      insert(:match_state_transition,
        match: match5,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 10:25:12]
      )

      insert(:match_state_transition,
        match: match6,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 08:21:12]
      )

      insert(:match_state_transition,
        match: match6,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-03-24 10:22:12]
      )

      insert(:match_state_transition,
        match: match6,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 10:52:12]
      )

      assert get_metric_value(:admin_metric_match_average_time, now, use_cache: false) == 102
    end

    test ":admin_metric_match_average_time for dash" do
      now = ~N[2020-03-24 15:24:21]

      match1 =
        insert(:match, dropoff_at: nil, pickup_at: nil, state: :charged, amount_charged: 1000)

      insert(:match_state_transition,
        match: match1,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 10:21:12]
      )

      insert(:match_state_transition,
        match: match1,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 10:20:12]
      )

      insert(:match_state_transition,
        match: match1,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 12:21:12]
      )

      match2 =
        insert(:match, dropoff_at: nil, pickup_at: nil, state: :charged, amount_charged: 1000)

      insert(:match_state_transition,
        match: match2,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-25 10:21:12]
      )

      insert(:match_state_transition,
        match: match2,
        to: :picked_up,
        inserted_at: ~N[2020-03-25 11:21:12]
      )

      match3 =
        insert(:match, dropoff_at: nil, pickup_at: nil, state: :charged, amount_charged: 1000)

      insert(:match_state_transition,
        match: match3,
        to: :assigning_driver,
        inserted_at: ~N[2020-03-24 10:21:12]
      )

      insert(:match_state_transition,
        match: match3,
        to: :picked_up,
        inserted_at: ~N[2020-03-24 11:21:12]
      )

      insert(:match, state: :pending)

      assert get_metric_value(:admin_metric_match_average_time, now, use_cache: false) == 90
    end

    test ":admin_metric_matches_in_progress" do
      now = DateTime.utc_now()
      insert_list(5, :accepted_match_state_transition, inserted_at: now)
      insert_list(5, :completed_match_state_transition, inserted_at: now)

      assert get_metric_value(:admin_metric_matches_in_progress, now, use_cache: false) == 5
    end

    test ":admin_metric_matches_this_month" do
      now = DateTime.utc_now()
      insert_list(5, :completed_match_state_transition, inserted_at: now)

      thirty_two_days_ago = now |> DateTime.add(-32 * 24 * 60 * 60)
      insert_list(5, :completed_match_state_transition, inserted_at: thirty_two_days_ago)

      assert get_metric_value(:admin_metric_matches_this_month, now, use_cache: false) == 5
    end

    test ":admin_metric_matches_unassigned" do
      now = DateTime.utc_now()
      insert_list(5, :assigning_driver_match_state_transition, inserted_at: now)
      insert_list(5, :accepted_match_state_transition, inserted_at: now)

      assert get_metric_value(:admin_metric_matches_unassigned, now, use_cache: false) == 5
    end

    test ":admin_metric_fulfillment_this_month" do
      now = DateTime.utc_now()

      thirty_two_days_ago = now |> DateTime.add(-32 * 24 * 60 * 60)
      insert_list(2, :completed_match, inserted_at: now)
      insert_list(5, :charged_match, inserted_at: now)
      insert_list(4, :canceled_match, inserted_at: now)
      insert_list(3, :en_route_to_pickup_match, inserted_at: now)

      insert_list(2, :completed_match, inserted_at: thirty_two_days_ago)
      insert_list(3, :charged_match, inserted_at: thirty_two_days_ago)
      insert_list(3, :canceled_match, inserted_at: thirty_two_days_ago)

      assert %{
               completed: 7,
               attempted: 0,
               canceled: 4,
               total: 11,
               percent: 63
             } = get_metric_value(:admin_metric_fulfillment_this_month, now, use_cache: false)
    end

    test ":admin_metric_fulfillment_today" do
      now = DateTime.utc_now()
      yesterday = now |> DateTime.add(-1 * 24 * 60 * 60)
      tomorrow = now |> DateTime.add(1 * 24 * 60 * 60)

      insert_list(2, :pending_match, inserted_at: now)
      insert_list(2, :completed_match, inserted_at: now)
      insert_list(5, :charged_match, inserted_at: now)
      insert_list(4, :canceled_match, inserted_at: now)
      insert_list(2, :canceled_match, inserted_at: now, cancel_charge: 100)
      insert_list(3, :en_route_to_pickup_match, inserted_at: now)
      insert_list(3, :scheduled_match, inserted_at: yesterday, pickup_at: now)

      insert_list(2, :scheduled_match, inserted_at: now, pickup_at: tomorrow)
      insert_list(2, :completed_match, inserted_at: yesterday)
      insert_list(3, :charged_match, inserted_at: yesterday)
      insert_list(3, :canceled_match, inserted_at: yesterday)
      insert_list(3, :en_route_to_pickup_match, inserted_at: yesterday)

      assert %{
               completed: 7,
               attempted: 2,
               canceled: 4,
               total: 13,
               percent: 69
             } = get_metric_value(:admin_metric_fulfillment_today, now, use_cache: false)
    end

    test "admin_metric_fulfillment_today with valid company" do
      now = DateTime.utc_now()
      yesterday = now |> DateTime.add(-1 * 24 * 60 * 60)
      tomorrow = now |> DateTime.add(1 * 24 * 60 * 60)

      %{location: %{company: company}} = shipper = insert(:shipper_with_location)

      insert_list(2, :pending_match, inserted_at: now, shipper: shipper)
      insert_list(2, :completed_match, inserted_at: now, shipper: shipper)
      insert_list(5, :charged_match, inserted_at: now, shipper: shipper)
      insert_list(4, :canceled_match, inserted_at: now, shipper: shipper)
      insert_list(2, :canceled_match, inserted_at: now, cancel_charge: 100)
      insert_list(3, :en_route_to_pickup_match, inserted_at: now)
      insert_list(3, :scheduled_match, inserted_at: yesterday, pickup_at: now)

      insert_list(2, :scheduled_match, inserted_at: now, pickup_at: tomorrow, shipper: shipper)
      insert_list(2, :completed_match, inserted_at: yesterday, shipper: shipper)
      insert_list(3, :charged_match, inserted_at: yesterday, shipper: shipper)
      insert_list(3, :canceled_match, inserted_at: yesterday, shipper: shipper)
      insert_list(3, :en_route_to_pickup_match, inserted_at: yesterday, shipper: shipper)

      assert %{
               completed: 7,
               attempted: 0,
               canceled: 4,
               total: 11,
               percent: 63
             } =
               get_metric_value("admin_metric_fulfillment_today_#{company.id}", now,
                 use_cache: false
               )
    end

    test "admin_metric_fulfillment_today handles no company" do
      now = DateTime.utc_now()

      assert %{
               completed: 0,
               attempted: 0,
               canceled: 0,
               total: 0,
               percent: 100
             } = get_metric_value("admin_metric_fulfillment_today_#{nil}", now, use_cache: false)
    end

    test "admin_metric_sla_today" do
      Cache.delete_all()

      [company1, company2, company3] = insert_list(3, :company, is_enterprise: true)

      location1 = insert(:location, company: company1)
      location2 = insert(:location, company: company2)
      location3 = insert(:location, company: company3)

      shipper1 = insert(:shipper, location: location1)
      shipper2 = insert(:shipper, location: location2)
      shipper3 = insert(:shipper, location: location3)

      now = DateTime.utc_now()
      past_15_min = DateTime.add(now, -15 * 60, :second)
      future_15_min = DateTime.add(now, 15 * 60, :second)

      insert_list(
        20,
        :match,
        shipper: shipper1,
        state: :completed,
        slas: [
          build(
            :match_sla,
            type: :delivery,
            end_time: future_15_min,
            completed_at: now
          )
        ]
      )

      insert_list(
        13,
        :match,
        shipper: shipper2,
        state: :canceled,
        slas: [
          build(
            :match_sla,
            type: :delivery,
            end_time: past_15_min,
            completed_at: now
          )
        ]
      )

      insert_list(
        24,
        :match,
        shipper: shipper3,
        state: :charged,
        slas: [
          build(
            :match_sla,
            type: :delivery,
            end_time: now,
            completed_at: now
          )
        ]
      )

      result =
        get_metric_value("admin_metric_sla_all_today", now, use_cache: false)
        |> Enum.sort_by(& &1.on_time, :asc)

      assert [
               %{company: _, on_time: 24, total: 24},
               %{company: _, on_time: 20, total: 20},
               %{company: _, on_time: 0, total: 13}
             ] = result |> Enum.sort_by(& &1.on_time, :desc)

      assert [%{company: _, on_time: 20, total: 20}] =
               get_metric_value("admin_metric_sla_completed_today", now, use_cache: false)
               |> Enum.sort_by(& &1.on_time, :asc)

      assert [%{company: _, on_time: 0, total: 13}] =
               get_metric_value("admin_metric_sla_canceled_today", now, use_cache: false)
               |> Enum.sort_by(& &1.on_time, :asc)
    end

    test "admin_metric_sla_month" do
      Cache.delete_all()

      [company1, company2, company3] = insert_list(3, :company, is_enterprise: true)

      location1 = insert(:location, company: company1)
      location2 = insert(:location, company: company2)
      location3 = insert(:location, company: company3)

      shipper1 = insert(:shipper, location: location1)
      shipper2 = insert(:shipper, location: location2)
      shipper3 = insert(:shipper, location: location3)

      one_day = 60 * 60 * 24

      first_day =
        DateTime.utc_now()
        |> Timex.beginning_of_month()
        |> DateTime.add(9 * 60 * 60, :second)

      insert_list(
        18,
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
        12,
        :match,
        shipper: shipper2,
        state: :canceled,
        slas: [
          build(
            :match_sla,
            type: :delivery,
            start_time: DateTime.add(first_day, one_day, :second),
            end_time: DateTime.add(first_day, one_day, :second) |> DateTime.add(-3 * 60, :second),
            completed_at:
              DateTime.add(first_day, one_day, :second) |> DateTime.add(1 * 60, :second)
          )
        ]
      )

      two_days = 2 * one_day

      insert_list(
        24,
        :match,
        shipper: shipper3,
        state: :charged,
        slas: [
          build(
            :match_sla,
            type: :delivery,
            start_time: DateTime.add(first_day, two_days, :second),
            end_time:
              DateTime.add(first_day, two_days, :second) |> DateTime.add(12 * 60, :second),
            completed_at:
              DateTime.add(first_day, two_days, :second) |> DateTime.add(2 * 60, :second)
          )
        ]
      )

      result =
        get_metric_value("admin_metric_sla_all_month", first_day, use_cache: false)
        |> Enum.sort_by(& &1.on_time, :asc)

      [
        %{company: _, on_time: 0, total: 12},
        %{company: _, on_time: 18, total: 18},
        %{company: _, on_time: 24, total: 24}
      ] = result

      assert [%{company: _, on_time: 18, total: 18}] =
               get_metric_value("admin_metric_sla_completed_month", first_day, use_cache: false)
               |> Enum.sort_by(& &1.on_time, :asc)

      assert [%{company: _, on_time: 0, total: 12}] =
               get_metric_value("admin_metric_sla_canceled_month", first_day, use_cache: false)
               |> Enum.sort_by(& &1.on_time, :asc)
    end
  end

  describe "longest_state/1" do
    test "with one simple match" do
      match1 =
        insert(:match,
          scheduled: false,
          pickup_at: nil,
          dropoff_at: nil,
          state: :charged,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match1,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:08:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:28:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:32:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:33:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:39:04]
      )

      assert get_metric_value(:admin_metric_state_lengths, ~N[2020-12-23 23:39:04],
               use_cache: false
             ) ==
               %{
                 assigning_driver: 40,
                 accepted: 2,
                 en_route_to_pickup: 12,
                 arrived_at_pickup: 2,
                 picked_up: 4
               }

      assert longest_state(~N[2020-12-23 23:39:04], use_cache: false) == :assigning_driver
    end

    test "with one simple scheduled match" do
      match1 =
        insert(:match,
          scheduled: true,
          pickup_at: ~N[2020-12-23 12:02:04],
          dropoff_at: ~N[2020-12-23 12:02:04],
          state: :charged,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match1,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:08:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:28:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:32:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:33:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:39:04]
      )

      assert get_metric_value(:admin_metric_state_lengths, ~N[2020-12-23 23:39:04],
               use_cache: false
             ) ==
               %{
                 assigning_driver: 40,
                 accepted: 0,
                 en_route_to_pickup: 12,
                 arrived_at_pickup: 2,
                 picked_up: 0
               }

      assert longest_state(~N[2020-12-23 23:39:04], use_cache: false) == :assigning_driver
    end

    test "with one complex match" do
      match2 =
        insert(:match,
          scheduled: false,
          state: :assigning_driver,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match2,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:57:05]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:58:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:08:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:28:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:32:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:33:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:39:04]
      )

      assert get_metric_value(:admin_metric_state_lengths, ~N[2020-12-23 13:40:04],
               use_cache: false
             ) ==
               %{
                 assigning_driver: 55,
                 accepted: 2,
                 en_route_to_pickup: 12,
                 arrived_at_pickup: 2,
                 picked_up: 34
               }

      assert longest_state(~N[2020-12-23 13:40:04], use_cache: false) == :assigning_driver
    end

    test "with one match without all transitions" do
      match3 =
        insert(:match,
          scheduled: false,
          state: :picked_up,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match3,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      assert get_metric_value(:admin_metric_state_lengths, ~N[2020-12-23 13:40:04],
               use_cache: false
             ) ==
               %{
                 assigning_driver: 40,
                 accepted: 2,
                 en_route_to_pickup: 12,
                 arrived_at_pickup: 2,
                 picked_up: 41
               }

      assert longest_state(~N[2020-12-23 13:40:04], use_cache: false) == :picked_up
    end

    test "with multiple matches" do
      match1 =
        insert(:match,
          scheduled: false,
          state: :charged,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match1,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:10:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:28:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:32:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:34:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:39:04]
      )

      match2 =
        insert(:match,
          scheduled: false,
          state: :assigning_driver,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match2,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:00:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:57:05]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:58:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:06:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:28:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:32:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :completed,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:33:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:39:04]
      )

      match3 =
        insert(:match,
          scheduled: false,
          state: :picked_up,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match3,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match3,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      assert get_metric_value(:admin_metric_state_lengths, ~N[2020-12-23 13:40:04],
               use_cache: false
             ) ==
               %{
                 assigning_driver: 45,
                 accepted: 2,
                 en_route_to_pickup: 12,
                 arrived_at_pickup: 2,
                 picked_up: 16
               }

      assert longest_state(~N[2020-12-23 13:40:04], use_cache: false) == :assigning_driver
    end

    test "with multiple simple matches" do
      match1 =
        insert(:match,
          scheduled: false,
          state: :charged,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match1,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:43:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:45:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 12:57:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 12:59:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:08:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:28:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:32:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:33:04]
      )

      insert(:match_state_transition,
        match: match1,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:39:04]
      )

      match2 =
        insert(:match,
          scheduled: false,
          state: :charged,
          inserted_at: ~N[2020-12-23 12:02:04],
          updated_at: ~N[2020-12-25 13:39:04]
        )

      insert(:match_state_transition,
        match: match2,
        from: :pending,
        to: :assigning_driver,
        inserted_at: ~N[2020-12-23 12:03:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :assigning_driver,
        to: :accepted,
        inserted_at: ~N[2020-12-23 12:53:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :accepted,
        to: :en_route_to_pickup,
        inserted_at: ~N[2020-12-23 12:55:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :en_route_to_pickup,
        to: :arrived_at_pickup,
        inserted_at: ~N[2020-12-23 13:07:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :arrived_at_pickup,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:09:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:18:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :picked_up,
        inserted_at: ~N[2020-12-23 13:38:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :picked_up,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:52:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :completed,
        to: :completed,
        inserted_at: ~N[2020-12-23 13:53:04]
      )

      insert(:match_state_transition,
        match: match2,
        from: :completed,
        to: :charged,
        inserted_at: ~N[2020-12-23 13:59:04]
      )

      assert get_metric_value(:admin_metric_state_lengths, ~N[2020-12-23 23:55:04],
               use_cache: false
             ) ==
               %{
                 assigning_driver: 45,
                 accepted: 2,
                 en_route_to_pickup: 12,
                 arrived_at_pickup: 2,
                 picked_up: 9
               }

      assert longest_state(~N[2020-12-23 23:55:04], use_cache: false) == :assigning_driver
    end
  end
end
