defmodule FraytElixirWeb.PaymentViewTest do
  use FraytElixirWeb.ConnCase, async: true
  import FraytElixirWeb.Admin.PaymentsView
  import FraytElixir.Factory
  alias FraytElixir.Accounts.{Shipper, Location, Company}

  setup [:login_as_admin]

  describe "driver_disabled" do
    test "with disabled driver" do
      disabled_driver = insert(:driver, state: :disabled)
      payment = insert(:payment_transaction, driver: disabled_driver)
      assert driver_disabled?(payment)
    end

    test "with no driver" do
      payment = insert(:payment_transaction, driver: nil)
      refute driver_disabled?(payment)
    end
  end

  describe "driver name" do
    test "with a driver" do
      driver = insert(:driver, first_name: "Jim", last_name: "Jones")
      payment = insert(:payment_transaction, driver: driver)
      assert driver_name(payment) == "Jim Jones"
    end

    test "with no driver" do
      payment = insert(:payment_transaction, driver: nil)
      assert driver_name(payment) == "-"
    end
  end

  describe "driver state" do
    test "with a driver" do
      driver = insert(:driver, first_name: "Jim", last_name: "Jones", state: "registered")
      payment = insert(:payment_transaction, driver: driver)
      assert driver_state(payment) == "(Registered)"
    end

    test "with no driver" do
      payment = insert(:payment_transaction, driver: nil)
      assert driver_state(payment) == ""
    end

    test "coupon_code" do
      match = insert(:match, coupon: nil)
      match2 = insert(:match, coupon: %FraytElixir.Shipment.Coupon{code: "whatever"})
      assert coupon_code(nil) == "-"
      assert coupon_code(match) == "-"
      assert coupon_code(match2) == "whatever"
    end

    test "payer_name" do
      %{payment_transaction: payment1} =
        insert(:driver_bonus, payment_transaction: build(:payment_transaction))

      payment2 = insert(:payment_transaction, transaction_type: "payout")

      payment3 =
        insert(:payment_transaction,
          match:
            build(:match,
              shipper: build(:shipper, first_name: "Burt", last_name: "Macklin", location: nil)
            )
        )

      payment1 |> FraytElixir.Repo.preload(:driver_bonus)

      assert payer_name(payment1) == "Frayt"
      assert payer_name(payment2) == "Frayt"
      assert payer_name(payment3) == "Burt Macklin"
    end
  end

  describe "admin_charges_live" do
    test "has_corporate_net_terms/1" do
      assert has_corporate_net_terms?(%Shipper{
               location: %Location{invoice_period: nil, company: %Company{invoice_period: 6}}
             }) == true

      assert has_corporate_net_terms?(%Shipper{
               location: %Location{invoice_period: nil, company: %Company{invoice_period: nil}}
             }) == false

      assert has_corporate_net_terms?(%Shipper{
               location: %Location{invoice_period: 4, company: %Company{invoice_period: 6}}
             }) == true

      assert has_corporate_net_terms?(%Shipper{
               location: %Location{invoice_period: 4, company: %Company{invoice_period: nil}}
             }) == true
    end
  end
end
