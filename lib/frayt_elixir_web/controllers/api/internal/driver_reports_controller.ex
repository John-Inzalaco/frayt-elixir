defmodule FraytElixirWeb.API.Internal.DriverReportsController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Reports
  alias FraytElixir.Convert
  import FraytElixirWeb.SessionHelper, only: [authorize_driver: 2]

  plug :authorize_driver

  action_fallback FraytElixirWeb.FallbackController

  def payout_report(conn, %{"days" => days} = params) when is_binary(days) do
    params = params |> Map.merge(%{"days" => Convert.to_integer(days)})
    payout_report(conn, params)
  end

  def payout_report(%{assigns: %{current_driver: driver}} = conn, %{"days" => days})
      when is_number(days) do
    conn
    |> render("driver_payout_report.json", Reports.driver_payout_report(driver.id, days))
  end

  def payout_report(%{assigns: %{current_driver: driver}} = conn, _params) do
    conn
    |> render("driver_payout_report.json", Reports.driver_payout_report(driver.id))
  end

  def payment_history(%{assigns: %{current_driver: driver}} = conn, _params) do
    conn
    |> render("driver_payment_history.json", Reports.driver_payment_history(driver.id))
  end

  def total_payments(conn, %{
        "type" => type,
        "range" => range
      })
      when is_bitstring(range),
      do: total_payments(conn, %{"type" => type, "range" => Convert.to_integer(range)})

  def total_payments(%{assigns: %{current_driver: driver}} = conn, %{
        "type" => "month",
        "range" => range
      }) do
    conn
    |> render("driver_payments.json", Reports.driver_payments(driver.id, :month, range))
  end

  def total_payments(%{assigns: %{current_driver: driver}} = conn, %{
        "type" => "day",
        "range" => range
      }) do
    conn
    |> render("driver_payments.json", Reports.driver_payments(driver.id, :day, range))
  end

  def match_payments(conn, %{"days" => days} = params) when is_binary(days) do
    params = params |> Map.merge(%{"days" => Convert.to_integer(days)})
    match_payments(conn, params)
  end

  def match_payments(%{assigns: %{current_driver: driver}} = conn, %{"days" => days}) do
    conn
    |> render("driver_payments.json", Reports.driver_match_payments(driver.id, days))
  end

  def notified_matches(conn, %{"days" => days} = params) when is_binary(days) do
    params = params |> Map.merge(%{"days" => Convert.to_integer(days)})
    notified_matches(conn, params)
  end

  def notified_matches(%{assigns: %{current_driver: driver}} = conn, %{"days" => days}) do
    conn
    |> render(
      "driver_payments.json",
      Reports.driver_notified_matches(driver.id, :day, days)
    )
  end
end
