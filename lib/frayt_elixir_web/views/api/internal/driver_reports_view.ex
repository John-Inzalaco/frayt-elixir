defmodule FraytElixirWeb.API.Internal.DriverReportsView do
  use FraytElixirWeb, :view

  import FraytElixirWeb.DisplayFunctions

  def render("driver_payments.json", %{"results" => results}) do
    %{
      response: results
    }
  end

  def render("driver_payout_report.json", %{"days_30" => days30, "days_90" => days90}) do
    %{
      response: %{"days_30" => days30, "days_90" => days90}
    }
  end

  def render("driver_payout_report.json", %{"payouts" => payouts}) do
    %{
      response: %{"payouts" => payouts}
    }
  end

  def render("driver_payment_history.json", %{"future" => future, "complete" => complete}) do
    %{
      response: %{
        "payouts_future" => cents_to_dollars(future),
        "payouts_complete" => cents_to_dollars(complete)
      }
    }
  end
end
