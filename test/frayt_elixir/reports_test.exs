defmodule FraytElixir.ReportsTest do
  use FraytElixir.DataCase, async: false

  import FraytElixir.Factory

  alias FraytElixir.Reports

  import FraytElixir.Test.ReportHelper

  describe "driver_payout_report" do
    test "returns json for report for base case" do
      driver = insert(:driver_with_wallet)
      tedious_setup(20, 3_00, driver)
      tedious_setup(4, 2_00, driver)

      assert %{
               "days_30" => 5_00,
               "days_90" => 5_00
             } = Reports.driver_payout_report(driver.id)
    end

    test "sum excludes matches for other drivers" do
      driver = insert(:driver_with_wallet)
      other_driver = insert(:driver)
      tedious_setup(20, 5_00, other_driver)
      tedious_setup(20, 3_00, driver)

      assert %{
               "days_30" => 3_00,
               "days_90" => 3_00
             } = Reports.driver_payout_report(driver.id)
    end

    test "sum excludes completed matches outside the time frame" do
      driver = insert(:driver_with_wallet)
      tedious_setup(91, 3_00, driver)

      assert %{
               "days_30" => 0_00,
               "days_90" => 0_00
             } = Reports.driver_payout_report(driver.id)
    end

    test "passing in 7 days returns sum of completed matches in past 7 days" do
      driver = insert(:driver_with_wallet)
      tedious_setup(1, 3_00, driver)
      tedious_setup(5, 3_00, driver)
      tedious_setup(10, 3_00, driver)

      assert %{"payouts" => 6_00} = Reports.driver_payout_report(driver.id, 7)
    end

    test "no matches returns 0 for both" do
      driver = insert(:driver_with_wallet)

      assert %{
               "days_30" => 0_00,
               "days_90" => 0_00
             } = Reports.driver_payout_report(driver.id)
    end

    test "more complicated setup" do
      driver = insert(:driver_with_wallet)
      tedious_setup(91, 15_00, driver)
      tedious_setup(89, 3_00, driver)
      tedious_setup(29, 5_00, driver)
      tedious_setup(20, 14_00, driver, :authorize)

      assert %{
               "days_30" => 5_00,
               "days_90" => 8_00
             } = Reports.driver_payout_report(driver.id)
    end
  end

  describe "driver_payment_history" do
    test "sum excludes matches for other drivers" do
      driver = insert(:driver_with_wallet)
      other_driver = insert(:driver)
      tedious_setup(20, 5_00, other_driver)
      tedious_setup(20, 3_00, driver)

      assert %{
               "future" => 0_00,
               "complete" => 3_00
             } = Reports.driver_payment_history(driver.id)
    end

    test "complete excludes completed matches within 24 hours" do
      driver = insert(:driver_with_wallet)
      tedious_setup(0, 3_00, driver)

      assert %{
               "future" => 0_00,
               "complete" => 0_00
             } = Reports.driver_payment_history(driver.id)
    end

    test "more complicated setup" do
      driver = insert(:driver_with_wallet)
      tedious_setup(0, 15_00, driver)
      tedious_setup(1, 3_00, driver)
      tedious_setup(100, 5_00, driver)
      tedious_setup(2, 14_00, driver, :authorize)

      assert %{
               "future" => 0_00,
               "complete" => 8_00
             } = Reports.driver_payment_history(driver.id)
    end
  end

  describe "driver_match_payments" do
    test "passing in 7 days returns payments and their associated matches in past 7 days" do
      driver = insert(:driver_with_wallet)

      %{payment_transaction: %{amount: pt_amount1}, match: %{shortcode: match_shortcode1}} =
        tedious_setup(1, 3_00, driver)

      %{payment_transaction: %{amount: pt_amount2}, match: %{shortcode: match_shortcode2}} =
        tedious_setup(5, 3_00, driver)

      tedious_setup(10, 3_00, driver)

      assert %{
               "results" => [
                 %{
                   amount: ^pt_amount1,
                   match: %{
                     shortcode: ^match_shortcode1
                   }
                 },
                 %{
                   amount: ^pt_amount2,
                   match: %{
                     shortcode: ^match_shortcode2
                   }
                 }
               ]
             } = Reports.driver_match_payments(driver.id, 7)
    end
  end

  describe "driver_payments" do
    test "passing in 7 days returns total revenue by day in past 7 days" do
      driver = insert(:driver_with_wallet)

      %{payment_transaction: _} = tedious_setup(1, 3_00, driver)

      %{payment_transaction: _} = tedious_setup(5, 3_00, driver)

      %{payment_transaction: _} = tedious_setup(5, 3_00, driver)

      tedious_setup(10, 3_00, driver)

      assert %{"results" => results} = Reports.driver_payments(driver.id, :day, 7)

      assert [
               %{amount: 300, day_of_week: _},
               %{amount: 600, day_of_week: _}
             ] = Enum.sort_by(results, & &1.amount)
    end

    test "passing in 7 months returns total revenue by month in past 7 months" do
      driver = insert(:driver_with_wallet)

      %{payment_transaction: %{amount: _pt_amount1}} = tedious_setup(0, 1_00, driver)

      %{payment_transaction: %{amount: _pt_amount2}} = tedious_setup(0, 1_00, driver)

      %{payment_transaction: %{amount: _pt_amount3}} = tedious_setup(32, 2_00, driver)

      %{payment_transaction: %{amount: _pt_amount3}} = tedious_setup(32, 2_00, driver)

      %{payment_transaction: %{amount: _pt_amount3}} = tedious_setup(64, 3_00, driver)

      %{payment_transaction: %{amount: _pt_amount3}} = tedious_setup(64, 3_00, driver)

      tedious_setup(240, 4_00, driver)

      assert %{"results" => results} = Reports.driver_payments(driver.id, :month, 3)

      assert [
               %{amount: 200, month: _},
               %{amount: 400, month: _},
               %{amount: 600, month: _}
             ] = Enum.sort_by(results, & &1.amount)
    end
  end

  describe "driver_matches" do
    test "passing in 2 months returns matches driver has been notified of in past 2 months" do
      driver = insert(:driver_with_wallet) |> set_driver_default_device()
      match1 = insert(:match)
      match2 = insert(:match)
      match3 = insert(:match)
      match4 = insert(:match)

      insert(:sent_notification,
        match: match1,
        driver: driver
      )

      insert(:sent_notification,
        match: match1,
        driver: driver
      )

      insert(:sent_notification,
        match: match2,
        driver: driver
      )

      insert(:sent_notification,
        match: match3,
        driver: driver,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60 * 32)
      )

      insert(:sent_notification,
        match: match3,
        driver: driver,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60 * 32)
      )

      insert(:sent_notification,
        match: match4,
        driver: driver,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60 * 120)
      )

      assert %{
               "results" => [%{amount: 2, month: _}, %{amount: 1, month: _}]
             } = Reports.driver_notified_matches(driver.id, :month, 2)
    end

    test "passing in 7 days returns matches driver has been notified of in past 7 days" do
      driver = insert(:driver_with_wallet) |> set_driver_default_device()
      match1 = insert(:match)
      match2 = insert(:match)
      match3 = insert(:match)
      match4 = insert(:match)

      insert(:sent_notification,
        match: match1,
        driver: driver
      )

      insert(:sent_notification,
        match: match1,
        driver: driver
      )

      insert(:sent_notification,
        match: match2,
        driver: driver
      )

      insert(:sent_notification,
        match: match3,
        driver: driver,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60 * 2)
      )

      insert(:sent_notification,
        match: match3,
        driver: driver,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60 * 2)
      )

      insert(:sent_notification,
        match: match4,
        driver: driver,
        inserted_at: DateTime.utc_now() |> DateTime.add(-1 * 24 * 60 * 60 * 20)
      )

      assert %{
               "results" => [%{amount: 2, day_of_week: _}, %{amount: 1, day_of_week: _}]
             } = Reports.driver_notified_matches(driver.id, :day, 7)
    end
  end
end
