defmodule FraytElixirWeb.Admin.PaymentsView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  alias FraytElixir.Payments
  alias FraytElixir.Payments.{DriverBonus, PaymentTransaction}
  alias FraytElixir.Shipment.{Coupon, Match}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Accounts.{Shipper, Location, Company}
  alias FraytElixir.Repo
  alias Ecto.Association.NotLoaded

  def get_next_payment_run(_timezone \\ nil) do
    Timex.now() |> Timex.shift(hours: 1) |> Timex.set(minute: 0, second: 0, microsecond: 0)
  end

  def driver_disabled?(%PaymentTransaction{driver: %Driver{state: :disabled}}), do: true

  def driver_disabled?(_), do: false

  def driver_unknown(%PaymentTransaction{driver: %Driver{}}), do: false
  def driver_unknown(_), do: "(Unknown)"

  def driver_name(%PaymentTransaction{driver: %Driver{} = driver}),
    do: full_name(driver)

  def driver_name(_), do: "-"

  def driver_state(%PaymentTransaction{driver: %Driver{state: driver_state}}),
    do: "(#{title_case(driver_state)})"

  def driver_state(_), do: ""

  def has_corporate_net_terms?(%Shipper{location: nil}), do: false

  def has_corporate_net_terms?(%Shipper{location: %Location{invoice_period: nil, company: nil}}),
    do: false

  def has_corporate_net_terms?(%Shipper{
        location: %Location{invoice_period: nil, company: %Company{invoice_period: nil}}
      }),
      do: false

  def has_corporate_net_terms?(_shipper), do: true

  def payer_name(%PaymentTransaction{driver_bonus: %DriverBonus{}}), do: "Frayt"
  def payer_name(%PaymentTransaction{transaction_type: "payout"}), do: "Frayt"
  def payer_name(%PaymentTransaction{match: match}), do: paid_by(match)

  def paid_by(%Match{shipper: %Shipper{} = shipper}) do
    if has_corporate_net_terms?(shipper), do: "Frayt", else: full_name(shipper)
  end

  def paid_by(_), do: "Unknown"

  def coupon_code(%Match{coupon: %Coupon{code: code}}), do: code
  def coupon_code(_), do: "-"

  def set_payment_match(payment, match), do: Map.put(payment, :match, match)

  def get_match_payments(%Match{payment_transactions: %NotLoaded{}} = match) do
    %Match{payment_transactions: payment_transactions} =
      match |> Repo.preload(payment_transactions: [:driver, :driver_bonus])

    payment_transactions
  end

  def get_match_payments(%Match{payment_transactions: payment_transactions}),
    do: payment_transactions

  defp get_charge_amount(%Match{state: state, cancel_charge: amount})
       when state in [:admin_canceled, :canceled],
       do: amount

  defp get_charge_amount(%Match{amount_charged: amount}), do: amount

  defp get_transfer_amount(%Match{state: state, cancel_charge_driver_pay: amount})
       when state in [:admin_canceled, :canceled],
       do: amount

  defp get_transfer_amount(%Match{driver_total_pay: amount}), do: amount
end
