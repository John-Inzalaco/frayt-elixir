defmodule FraytElixirWeb.API.Internal.DriverReportsControllerTest do
  use FraytElixirWeb.ConnCase

  import FraytElixirWeb.Test.LoginHelper
  alias FraytElixir.Drivers.Driver
  import FraytElixir.Test.ReportHelper

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "driver_payout_report" do
    setup [:login_as_driver_with_wallet]

    test "no matches returns json with report info", %{conn: conn, driver: %Driver{} = _driver} do
      conn = get(conn, Routes.api_v2_driver_report_type_path(conn, :payout_report, ".1"))

      assert %{
               "days_30" => 0,
               "days_90" => 0
             } = json_response(conn, 200)["response"]
    end

    test "passing in 7 days returns payments completed in the past 7 days", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      tedious_setup(0, 15_00, driver)
      tedious_setup(1, 3_00, driver)
      tedious_setup(10, 5_00, driver)
      tedious_setup(2, 14_00, driver, :authorize)

      conn =
        get(conn, Routes.api_v2_driver_report_type_path(conn, :payout_report, ".1"), %{
          days: 7
        })

      assert %{
               "payouts" => 18_00
             } = json_response(conn, 200)["response"]
    end

    test "passing in nil for days returns payments completed in the default 30 and 90 day timeframes",
         %{
           conn: conn,
           driver: %Driver{} = driver
         } do
      tedious_setup(0, 15_00, driver)
      tedious_setup(1, 3_00, driver)
      tedious_setup(10, 5_00, driver)
      tedious_setup(40, 5_00, driver)
      tedious_setup(2, 14_00, driver, :authorize)

      conn =
        get(conn, Routes.api_v2_driver_report_type_path(conn, :payout_report, ".1"), %{
          days: nil
        })

      assert %{
               "days_30" => 23_00,
               "days_90" => 28_00
             } = json_response(conn, 200)["response"]
    end
  end

  describe "driver_payment_history" do
    setup [:login_as_driver_with_wallet]

    test "no matches returns json with payment history", %{
      conn: conn,
      driver: %Driver{} = _driver
    } do
      conn = get(conn, Routes.api_v2_driver_report_type_path(conn, :payment_history, ".1"))

      assert %{
               "payouts_future" => 0.0,
               "payouts_complete" => 0.0
             } = json_response(conn, 200)["response"]
    end

    test "payouts are in dollars", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      tedious_setup(0, 15_00, driver)
      tedious_setup(1, 3_00, driver)
      tedious_setup(100, 5_00, driver)
      tedious_setup(2, 14_00, driver, :authorize)

      conn = get(conn, Routes.api_v2_driver_report_type_path(conn, :payment_history, ".1"))

      assert %{
               "payouts_future" => 0.0,
               "payouts_complete" => 8.0
             } = json_response(conn, 200)["response"]
    end
  end

  describe "driver_itemized_payment_history" do
    setup [:login_as_driver_with_wallet]

    test "returns payments and their associated matches completed within the specified range", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      %{payment_transaction: %{amount: pt_amount1}, match: %{shortcode: match_shortcode1}} =
        tedious_setup(0, 15_00, driver)

      %{payment_transaction: %{amount: pt_amount2}, match: %{shortcode: match_shortcode2}} =
        tedious_setup(1, 3_00, driver)

      %{match: _match3} = tedious_setup(100, 5_00, driver)
      %{match: _match4} = tedious_setup(2, 14_00, driver, :authorize)

      conn =
        get(conn, Routes.api_v2_driver_report_type_path(conn, :match_payments, ".1"), %{
          "days" => 7
        })

      assert [
               %{
                 "amount" => ^pt_amount1,
                 "match" => %{
                   "shortcode" => ^match_shortcode1
                 }
               },
               %{
                 "amount" => ^pt_amount2,
                 "match" => %{
                   "shortcode" => ^match_shortcode2
                 }
               }
             ] = json_response(conn, 200)["response"]
    end
  end

  describe "driver_notified_matches" do
    setup [:login_as_driver_with_wallet]

    test "returns total matches by month in specified range", %{
      conn: conn,
      driver: %Driver{} = driver
    } do
      match = insert(:match)

      insert(:sent_notification,
        match: match,
        driver: driver
      )

      conn =
        get(conn, Routes.api_v2_driver_report_type_path(conn, :notified_matches, ".1"), %{
          "days" => 7
        })

      assert [%{"amount" => 1, "day_of_week" => _, "day_of_week_name" => _}] =
               json_response(conn, 200)["response"]
    end
  end

  describe "driver_total_payments" do
    setup [:login_as_driver_with_wallet]

    test "returns total matches by month in specified range", %{
      conn: conn,
      driver: %Driver{} = _driver
    } do
      conn =
        get(conn, Routes.api_v2_driver_report_type_path(conn, :total_payments, ".1"), %{
          "type" => "day",
          "range" => 7
        })

      assert [] = json_response(conn, 200)["response"]
    end
  end
end
