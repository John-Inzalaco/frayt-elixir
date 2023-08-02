defmodule FraytElixir.PaymentsTest do
  use FraytElixir.DataCase

  alias FraytElixir.Matches
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Match, MatchStop}
  alias FraytElixir.Payments
  alias FraytElixir.Payments.{CreditCard, DriverBonus, PaymentTransaction}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Screenings.BackgroundCheck

  import FraytElixir.Factory

  import FraytElixir.Test.StartMatchSupervisor
  import FraytElixir.Test.WebhookHelper

  setup do
    FakeSlack.clear_messages()
    start_match_webhook_sender(self())
  end

  setup :start_match_supervisor

  describe "credit_cards" do
    alias FraytElixir.Payments.CreditCard

    @valid_attrs %{stripe_card: "some stripe_card", stripe_token: "some stripe_token"}

    defp valid_card_attrs(attrs \\ %{}) do
      shipper = insert(:shipper)

      attrs
      |> Enum.into(@valid_attrs)
      |> Map.put(:shipper, shipper)
    end

    def credit_card_fixture(attrs \\ %{}) do
      {:ok, credit_card} = Payments.create_credit_card(valid_card_attrs(attrs))
      credit_card
    end

    test "create_credit_card/1 with valid data creates a credit_card for a shipper without a stripe customer" do
      card_attrs = valid_card_attrs()
      assert {:ok, %CreditCard{} = credit_card} = Payments.create_credit_card(card_attrs)
      saved_card = Payments.get_credit_card!(credit_card.id)
      assert saved_card.stripe_card == "some stripe_card"
      assert saved_card.shipper.id == card_attrs.shipper.id
      assert String.length(saved_card.last4) == 4
      assert String.length(saved_card.shipper.stripe_customer_id) > 0
    end

    test "create_credit_card/1 for a shipper with an existing stripe customer id" do
      shipper = insert(:shipper, stripe_customer_id: "cus_7890")

      assert {:ok, %CreditCard{} = credit_card} =
               Payments.create_credit_card(@valid_attrs |> Map.put(:shipper, shipper))

      saved_card = Payments.get_credit_card!(credit_card.id)
      assert saved_card.shipper.id == shipper.id
      assert String.length(saved_card.last4) == 4
      assert saved_card.shipper.stripe_customer_id == "cus_7890"
    end

    test "create_credit_card/1 for a shipper with an existing stripe customer id and an existing card should overwrite with new card" do
      shipper = insert(:shipper, stripe_customer_id: "cus_7890")

      assert {:ok, %CreditCard{} = old_credit_card} =
               Payments.create_credit_card(@valid_attrs |> Map.put(:shipper, shipper))

      assert {:ok, %CreditCard{} = new_credit_card} =
               Payments.create_credit_card(
                 @valid_attrs
                 |> Map.put(:stripe_card, "my new card")
                 |> Map.put(:shipper, shipper)
               )

      saved_card = Payments.get_credit_card!(new_credit_card.id)
      assert saved_card.shipper.id == shipper.id
      assert String.length(saved_card.last4) == 4
      assert saved_card.shipper.stripe_customer_id == "cus_7890"

      refute Repo.get(CreditCard, old_credit_card.id)
    end

    test "create credit_card with previously used token responds with error" do
      assert {:error, :card_error, error_message} =
               Payments.create_credit_card(valid_card_attrs(%{stripe_token: "used token"}))

      assert String.contains?(error_message, "more than once")
    end

    test "create credit_card with garbage token responds with error" do
      assert {:error, :card_error, error_message} =
               Payments.create_credit_card(valid_card_attrs(%{stripe_token: "garbage"}))

      assert String.contains?(error_message, "No such token")
    end

    test "get card for shipper" do
      card = credit_card_fixture() |> Repo.preload([:shipper])
      {:ok, %CreditCard{} = found_card} = Payments.get_credit_card_for_shipper(card.shipper)
      assert found_card.last4 == card.last4
    end
  end

  describe "authorize" do
    test "authorize creates a payment transaction for the match" do
      credit_card = insert(:credit_card)

      match = insert(:match, shipper: credit_card.shipper)
      {:ok, payment_changeset} = Payments.authorize_match(match, 1500)

      assert %PaymentTransaction{
               status: "succeeded",
               payment_provider_response: response,
               transaction_type: :authorize,
               amount: 1500
             } = payment_changeset

      assert String.length(response) > 0
      charge = Jason.decode!(response)
      assert charge["amount"] == 1500
    end

    test "authorizing an invalid payment transaction returns an error" do
      credit_card = insert(:credit_card, stripe_card: "bad_card")

      match = insert(:match, shipper: credit_card.shipper)

      {:error, %Stripe.Error{extra: extra}} = Payments.authorize_match(match, 1500)

      assert extra.card_code == :card_declined
      assert extra.decline_code == "generic_decline"
    end

    test "authorizing for a company who pays by invoicing does not authorize to run card" do
      invoiceable_shipper = insert(:shipper_with_location)

      match =
        insert(:match, shipper: invoiceable_shipper)
        |> Repo.preload(shipper: [location: [:company]])

      assert {:ok, message} = Payments.authorize_match(match, 1500)

      assert String.contains?(message, "No payment required")
    end

    test "authorizing shipper with a credit card but who belongs to a company who pays by invoice does not charge the card" do
      invoiceable_shipper = insert(:shipper_with_location)
      insert(:credit_card, shipper: invoiceable_shipper)

      match =
        insert(:match, shipper: invoiceable_shipper)
        |> Repo.preload(shipper: [location: [:company]])

      assert {:ok, message} = Payments.authorize_match(match, 1500)
      assert String.contains?(message, "No payment required")
    end
  end

  describe "charge" do
    test "charge captures payment" do
      driver = insert(:driver_with_wallet)

      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver, amount_charged: 2000)
        )

      assert {:ok,
              %PaymentTransaction{
                status: "succeeded",
                transaction_type: :capture,
                amount: 2000,
                match_id: match_id
              }} = Payments.charge_match(match)

      assert match_id == match.id
    end

    test "charge captures payment and does not pay driver if driver was already paid" do
      driver = insert(:driver_with_wallet)
      match = insert(:match, state: :completed, driver: driver, amount_charged: 2000)

      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: match
        )

      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :transfer,
          status: "succeeded",
          match: match
        )

      assert {:ok,
              %PaymentTransaction{
                status: "succeeded",
                transaction_type: :capture,
                amount: 2000
              }} = Payments.charge_match(match)

      %{
        state: :completed,
        payment_transactions: transactions
      } = Repo.get!(Match, match.id) |> Repo.preload(:payment_transactions)

      transfers =
        transactions
        |> Enum.filter(&(&1.transaction_type == :transfer))
        |> Enum.count()

      assert transfers == 1
    end

    test "attempting to capture payment with no prior auth" do
      match = insert(:match, state: :completed) |> Repo.preload(:payment_transactions)
      assert {:error, message} = Payments.charge_match(match)
      assert String.contains?(message, "No prior auth")
    end

    test "fradulent card catch" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          transaction_reason: :charge,
          external_id: "fradulent",
          status: "succeeded",
          match: build(:match, state: :completed, amount_charged: nil, driver_total_pay: nil)
        )

      assert {:error,
              %PaymentTransaction{
                status: "error",
                payment_provider_response: response
              }} = Payments.charge_match(match)

      # Generic decline message preferable to fradulent notification for scammers
      assert String.contains?(response, "Your card was declined")
      assert String.contains?(response, "http_status: 402")
    end

    test "attempting invalid capture records error" do
      %PaymentTransaction{match: match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          transaction_reason: :charge,
          external_id: "garbage",
          status: "succeeded",
          match: build(:match, state: :completed, amount_charged: nil, driver_total_pay: nil)
        )

      assert {:error,
              %PaymentTransaction{
                status: "error",
                payment_provider_response: response
              }} = Payments.charge_match(match)

      assert String.contains?(response, "No such charge")
    end

    test "charging for a company who pays by invoicing charges Frayt" do
      invoiceable_shipper = insert(:shipper_with_location)
      driver = insert(:driver_with_wallet)

      match =
        insert(:match,
          state: :completed,
          driver: driver,
          shipper: invoiceable_shipper,
          amount_charged: 2500,
          driver_total_pay: 2000
        )

      assert {:ok,
              %PaymentTransaction{
                status: "succeeded",
                transaction_type: :capture,
                amount: 2000,
                payment_provider_response: response
              }} = Payments.charge_match(match)

      stripe_charge = Jason.decode!(response)
      assert stripe_charge["payment_method"] == "card_12345"
      assert stripe_charge["customer"] == "cus_12345"
    end

    test "failure charging invoicing customer records error" do
      invoiceable_shipper = insert(:shipper_with_location)

      # 777 is a magic number to trigger a strip error via the fake
      match =
        insert(:match, shipper: invoiceable_shipper, amount_charged: 25_00, driver_total_pay: 7_77)

      assert {:error,
              %PaymentTransaction{
                status: "error",
                payment_provider_response: response
              }} = Payments.charge_match(match)

      assert String.contains?(response, "declined")
    end

    test "charging a match with an increased total_price that has already been charged will create a new charge with only the difference in price" do
      %CreditCard{shipper: shipper} = insert(:credit_card)

      initial_charge = 20_00
      updated_charge = 128_33

      match =
        %Match{
          match_stops: [
            %MatchStop{
              id: stop_id,
              items: [
                %{
                  id: item_id
                }
              ]
            }
          ]
        } =
        insert(:signed_match,
          match_stops: build_match_stops_with_items([:signed]),
          fees: [
            build(:match_fee, type: :base_fee, amount: initial_charge)
          ],
          amount_charged: initial_charge,
          shipper: shipper,
          vehicle_class: 1,
          service_level: 1,
          payment_transactions: []
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, authorized_match} = Matches.update_and_authorize_match(match)
      assert authorized_match.amount_charged == 2834

      {:ok,
       %PaymentTransaction{
         id: first_charge_transaction_id,
         status: _first_charge_transaction_status,
         amount: _first_charged_amount
       }} = Payments.charge_match(authorized_match)

      {:ok, updated_match} =
        Matches.update_match(authorized_match, %{
          match_stops: [
            %{
              id: stop_id,
              has_load_fee: true,
              items: [
                %{
                  id: item_id,
                  weight: 500
                }
              ]
            }
          ],
          state: :completed
        })

      assert updated_match.amount_charged == updated_charge

      updated_match =
        Repo.get!(Match, updated_match.id)
        |> Repo.preload(payment_transactions: [:driver_bonus], shipper: [:credit_card])

      {:ok,
       %PaymentTransaction{
         id: _second_charge_transaction_id,
         status: second_charge_transaction_status,
         amount: _second_charged_amount
       }} = Payments.charge_match(updated_match)

      %PaymentTransaction{canceled_at: nil} =
        Repo.get(PaymentTransaction, first_charge_transaction_id)

      assert "succeeded" == second_charge_transaction_status

      difference_in_charge_pricing = updated_charge - initial_charge
      assert difference_in_charge_pricing == 108_33
    end

    test "charging a match that has an increased total_price will create a new authorization with the total_price" do
      %CreditCard{shipper: shipper} = insert(:credit_card)

      match =
        %Match{
          match_stops: [
            %MatchStop{
              id: stop_id,
              items: [
                %{
                  id: item_id
                }
              ]
            }
          ]
        } =
        insert(:pending_match,
          match_stops: build_match_stops_with_items([:signed]),
          fees: [
            build(:match_fee, type: :base_fee, amount: 1500)
          ],
          amount_charged: 1500,
          shipper: shipper,
          vehicle_class: 1,
          service_level: 1
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, authorized_match} = Matches.update_and_authorize_match(match)

      assert authorized_match.amount_charged == 2834

      %PaymentTransaction{id: original_transaction_id} =
        Repo.get_by(PaymentTransaction, match_id: authorized_match.id)

      {:ok, updated_match} =
        Matches.update_match(authorized_match, %{
          match_stops: [
            %{
              id: stop_id,
              has_load_fee: true,
              items: [
                %{
                  id: item_id,
                  weight: 500
                }
              ]
            }
          ],
          state: :completed
        })

      assert updated_match.amount_charged == 128_33

      updated_match =
        updated_match
        |> Repo.preload(shipper: :credit_card)

      {:ok,
       %PaymentTransaction{
         id: new_transaction_id,
         status: new_transaction_status,
         amount: charged_amount
       }} = Payments.charge_match(updated_match)

      %PaymentTransaction{canceled_at: old_transaction_canceled_at} =
        Repo.get(PaymentTransaction, original_transaction_id)

      refute new_transaction_id == original_transaction_id
      assert "succeeded" == new_transaction_status
      assert old_transaction_canceled_at

      assert 128_33 = charged_amount
    end

    test "charging a match that has an decreased total_price will capture with the total_price" do
      %CreditCard{shipper: shipper} = insert(:credit_card)
      driver = insert(:driver_with_wallet)

      match_stop =
        insert(:match_stop,
          has_load_fee: true,
          items: [build(:match_stop_item, weight: 500)],
          index: 0
        )

      match =
        insert(:pending_match,
          shipper: shipper,
          driver: driver,
          vehicle_class: 1,
          service_level: 1,
          total_distance: 21.4,
          amount_charged: 4695,
          fees: [
            build(:match_fee, type: :base_fee, amount: 2834),
            build(:match_fee, type: :load_fee, amount: 1999)
          ],
          match_stops: [match_stop],
          payment_transactions: []
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, authorized_match} = Matches.update_and_authorize_match(match)

      %{match_stops: [_new_match_stop | _]} = authorized_match
      assert authorized_match.amount_charged == 128_33

      {:ok, updated_match} =
        Matches.update_match(authorized_match, %{
          match_stops: [
            %{
              id: match_stop.id,
              has_load_fee: false
            }
          ],
          state: :completed
        })

      updated_match = updated_match |> Repo.preload(shipper: :credit_card)

      authorization_payment_transaction =
        %PaymentTransaction{id: original_transaction_id} =
        Repo.get_by(PaymentTransaction, match_id: authorized_match.id)

      PaymentTransaction.changeset(authorization_payment_transaction, %{
        external_id: "stripe_id_expected_amount_2696"
      })
      |> Repo.update()

      updated_match = updated_match |> Repo.preload([:payment_transactions], force: true)

      assert updated_match.amount_charged == 2834

      {:ok,
       %PaymentTransaction{
         id: new_transaction_id,
         status: new_transaction_status,
         amount: charged_amount,
         transaction_reason: :charge
       }} = Payments.charge_match(updated_match)

      %PaymentTransaction{canceled_at: old_transaction_canceled_at} =
        Repo.get(PaymentTransaction, original_transaction_id)

      refute new_transaction_id == original_transaction_id
      assert "succeeded" == new_transaction_status
      refute old_transaction_canceled_at

      assert 2834 = charged_amount
    end

    test "charging a match that has a decreased total_price that has already been charged will create a new refund with only the difference in price" do
      %CreditCard{shipper: shipper} = insert(:credit_card)
      driver = insert(:driver_with_wallet)

      match_stop =
        insert(:match_stop,
          has_load_fee: true,
          items: [build(:match_stop_item, weight: 500)],
          index: 0
        )

      match =
        insert(:pending_match,
          shipper: shipper,
          driver: driver,
          vehicle_class: 1,
          service_level: 1,
          total_distance: 21.4,
          match_stops: [match_stop],
          payment_transactions: []
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, authorized_match} = Matches.update_and_authorize_match(match)
      %{match_stops: [_new_match_stop | _]} = authorized_match
      assert authorized_match.amount_charged == 128_33

      {:ok,
       %PaymentTransaction{
         id: first_charge_transaction_id,
         status: _first_charge_transaction_status,
         amount: first_charged_amount
       }} = Payments.charge_match(authorized_match)

      {:ok, updated_match} =
        Matches.update_match(authorized_match, %{
          match_stops: [
            %{
              id: match_stop.id,
              has_load_fee: false
            }
          ]
        })

      updated_match =
        Repo.get!(Match, updated_match.id)
        |> Repo.preload(payment_transactions: [:driver_bonus], shipper: [:credit_card])

      assert updated_match.amount_charged == 2834

      {:ok,
       %PaymentTransaction{
         id: _second_charge_transaction_id,
         status: _second_charge_transaction_status,
         transaction_type: second_transaction_type,
         amount: second_refund_amount
       }} = Payments.charge_match(updated_match)

      %PaymentTransaction{canceled_at: nil} =
        Repo.get(PaymentTransaction, first_charge_transaction_id)

      assert :refund == second_transaction_type
      assert second_refund_amount < first_charged_amount
    end
  end

  describe "create_wallet" do
    test "creates wallet for driver" do
      d = insert(:driver, wallet_state: nil)
      assert {:ok, %Driver{wallet_state: :UNCLAIMED}} = Payments.create_wallet(d)
    end

    test "handles timeout" do
      d = insert(:driver, user: build(:user, email: "timeout@email.com"))

      assert {:error, ":timeout"} = Payments.create_wallet(d)
    end

    test "handles error status code" do
      d = insert(:driver, wallet_state: nil, birthdate: ~D[1901-01-01])

      assert {:error, "Internal Server Error: Could not initialize user"} =
               Payments.create_wallet(d)
    end
  end

  describe "transfer_driver_pay" do
    test "perform driver transfer transfers driver total pay" do
      %Driver{id: driver_id} = driver = insert(:driver_with_wallet)

      match = insert(:match, state: :completed, driver: driver, driver_total_pay: 2000)

      assert {:ok,
              %PaymentTransaction{
                id: payment_txn_id,
                status: "succeeded",
                transaction_type: :transfer,
                payment_provider_response: response
              }} = Payments.transfer_driver_pay(match)

      assert %PaymentTransaction{amount: 2000, driver_id: ^driver_id} =
               Repo.get(PaymentTransaction, payment_txn_id)

      transfer = Jason.decode!(response)
      assert transfer["amount"] == 2000
    end

    test "fails if match has no driver" do
      match = insert(:match, state: :completed, driver: nil, driver_total_pay: 2000)

      assert {:error, "No payment transaction created"} = Payments.transfer_driver_pay(match)
    end

    test "transfer for account billing shipper transfers driver total pay" do
      assert %Driver{} = driver = insert(:driver_with_wallet)

      invoiceable_shipper = insert(:shipper_with_location)

      match =
        insert(:match,
          state: :completed,
          driver: driver,
          shipper: invoiceable_shipper,
          driver_total_pay: 2000
        )

      assert {:ok,
              %PaymentTransaction{
                status: "succeeded",
                transaction_type: :transfer
              }} = Payments.transfer_driver_pay(match)
    end

    test "transfer driver bonus creates correct records with a match" do
      driver = insert(:driver_with_wallet)
      admin_user = insert(:admin_user)

      match =
        insert(:match,
          state: :completed,
          driver: driver
        )

      assert {:ok, _} =
               Payments.transfer_driver_bonus(%{
                 driver: driver,
                 amount: 1200,
                 notes: nil,
                 match: match,
                 admin_user: admin_user
               })

      payment =
        Payments.list_charges()
        |> List.first()

      assert payment.status == "succeeded"
      assert payment.amount == 1200
      assert payment.match_id == match.id
      assert payment.driver_bonus.driver_id == driver.id
      assert payment.driver_bonus.notes == nil
      assert payment.driver_bonus.created_by_id == admin_user.id
    end

    test "list_charges/1 with a match id returns proper payment transactions" do
      match = insert(:match)
      [payment1, payment2, payment3] = insert_list(3, :payment_transaction, match: match)
      insert_list(2, :payment_transaction)

      %DriverBonus{payment_transaction: payment4} =
        insert(:driver_bonus, payment_transaction: build(:payment_transaction, match: match))

      correct_payments = Enum.sort([payment1.id, payment2.id, payment3.id, payment4.id])
      payments = Payments.list_charges(match.id)
      assert Enum.count(payments) == 4
      assert Enum.sort(Enum.map(payments, & &1.id)) == correct_payments
    end

    test "transfer driver bonus creates correct records without a match" do
      driver = insert(:driver_with_wallet)
      admin_user = insert(:admin_user)

      assert {:ok, _} =
               Payments.transfer_driver_bonus(%{
                 driver: driver,
                 amount: 1200,
                 notes: "some notes",
                 match: nil,
                 admin_user: admin_user
               })

      payment =
        Payments.list_charges()
        |> List.first()

      assert payment.status == "succeeded"
      assert payment.amount == 1200
      assert payment.match_id == nil
      assert payment.driver_bonus.driver_id == driver.id
      assert payment.driver_bonus.notes == "some notes"
      assert payment.driver_bonus.created_by_id == admin_user.id
    end

    test "invalid transfer records error" do
      driver = insert(:driver, wallet_state: nil)

      match = insert(:match, state: :completed, driver: driver, driver_total_pay: 2000)

      assert {:error,
              %PaymentTransaction{
                status: "error",
                payment_provider_response: response
              }} = Payments.transfer_driver_pay(match)

      error = Jason.decode!(response)
      assert error["status"] == "FAILED"
    end

    test "invalid transfer sends slack notification to payments" do
      driver = insert(:driver, wallet_state: nil)

      match = insert(:match, state: :completed, driver: driver, driver_total_pay: 2000)

      assert {:error, %PaymentTransaction{status: "error"}} = Payments.transfer_driver_pay(match)

      assert [{_, message}] = FakeSlack.get_messages("#payments-test")
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, match.shipper.first_name)
    end

    test "transfer timeout sends slack notification to payments" do
      driver = insert(:driver_with_wallet)

      match =
        insert(:match,
          state: :completed,
          driver: driver,
          driver_total_pay: 666
        )

      assert {:error, %PaymentTransaction{status: "error", payment_provider_response: nil}} =
               Payments.transfer_driver_pay(match)

      assert [{_, message}] = FakeSlack.get_messages("#payments-test")
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, match.shipper.first_name)
    end

    test "The driver amount cannot be decreased" do
      %{shipper: shipper} = insert(:credit_card)

      match =
        %Match{
          match_stops: [%MatchStop{id: stop_id, items: [%{id: item_id}]}]
        } =
        insert(:charged_match,
          match_stops: build_match_stops_with_items([:signed]),
          fees: [build(:match_fee, type: :base_fee, amount: 1500)],
          amount_charged: 1500,
          shipper: shipper
        )
        |> Repo.preload(shipper: :credit_card)

      {:ok, updated_match} =
        Matches.update_match(match, %{
          match_stops: [
            %{
              id: stop_id,
              has_load_fee: true,
              items: [
                %{
                  id: item_id,
                  weight: 500
                }
              ]
            }
          ],
          fees: [
            %{type: :base_fee, amount: 2500, description: "A fee", driver_amount: 75}
          ]
        })

      assert %{state: :completed} = updated_match

      assert {:error, "No payment transaction created"} =
               Payments.transfer_driver_pay(updated_match)
    end

    test "The driver amount can be increased" do
    end
  end

  describe "payments" do
    test "list_charges/0 returns list of all payments" do
      insert_list(12, :payment_transaction)
      assert Enum.count(Payments.list_charges()) == 12
    end

    test "list_charges/1 returns proper set of payments" do
      ready_drivers = insert_list(5, :payment_transaction, status: "ready")
      insert_list(15, :payment_transaction, status: "paid")

      Enum.each(
        ready_drivers,
        &insert(:shipper_match_coupon, match: &1.match, shipper: &1.match.shipper)
      )

      assert Enum.count(Payments.list_charges()) == 20

      assert Enum.count(
               Payments.list_charges(%{
                 page: 0,
                 per_page: 20,
                 order: :asc,
                 order_by: :status,
                 query: nil
               })
               |> elem(0)
             ) == 20

      payments =
        Payments.list_charges(%{
          page: 7,
          per_page: 2,
          order: :asc,
          order_by: :status,
          query: nil
        })
        |> elem(0)

      assert List.first(payments).status == "paid"
      assert List.last(payments).status == "ready"

      payments =
        Payments.list_charges(%{
          page: 2,
          per_page: 2,
          order: :asc,
          order_by: :status,
          query: "coupon"
        })
        |> elem(0)

      assert Enum.count(payments) == 1
      assert List.first(payments).status == "ready"
    end

    test "list_charges/1 can order by shipper/payer name when payer isn't shipper" do
      payment1 =
        insert(:payment_transaction,
          match:
            build(:match,
              shipper:
                build(:shipper,
                  first_name: "Shipper",
                  last_name: "A",
                  location:
                    build(:location,
                      invoice_period: nil,
                      company: build(:company, invoice_period: 3)
                    )
                )
            )
        )

      payment2 =
        insert(:payment_transaction,
          match:
            build(:match,
              shipper: build(:shipper, first_name: "Shipper", last_name: "B", location: nil)
            )
        )

      payment3 =
        insert(:payment_transaction,
          match:
            build(:match,
              shipper: build(:shipper, first_name: "Shipper", last_name: "C", location: nil)
            )
        )

      payment4 =
        insert(:payment_transaction,
          match:
            build(:match,
              shipper:
                build(:shipper,
                  first_name: "Shipper",
                  last_name: "D",
                  location:
                    build(:location,
                      invoice_period: 3,
                      company: build(:company, invoice_period: 2)
                    )
                )
            )
        )

      payment5 =
        insert(:payment_transaction,
          match:
            build(:match,
              shipper:
                build(:shipper,
                  first_name: "Shipper",
                  last_name: "D",
                  location:
                    build(:location,
                      invoice_period: nil,
                      company: build(:company, invoice_period: nil)
                    )
                )
            )
        )

      payments =
        Payments.list_charges(%{
          page: 0,
          per_page: 10,
          order: :asc,
          order_by: :payment_payer_name,
          query: nil
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      order = [payment1.id, payment4.id, payment2.id, payment3.id, payment5.id]
      assert payments == order

      payments =
        Payments.list_charges(%{
          page: 0,
          per_page: 10,
          order: :desc,
          order_by: :payment_payer_name,
          query: nil
        })
        |> elem(0)
        |> Enum.map(& &1.id)

      assert payments == Enum.reverse(order)
    end

    test "PaymentTransaction.filter_by_query doesn't exclude payments without coupons unless searching by coupon" do
      payment1 =
        insert(:payment_transaction, status: "ready", match: build(:match, shortcode: "abc"))

      insert(:payment_transaction, status: "not charged", match: build(:match, shortcode: "abc"))

      insert(:shipper_match_coupon,
        match: payment1.match,
        shipper: payment1.match.shipper,
        coupon: build(:coupon, code: "welcome123")
      )

      {[%PaymentTransaction{}, %PaymentTransaction{}], 1} =
        Payments.list_charges(%{
          page: 0,
          per_page: 2,
          order: :asc,
          order_by: :status,
          query: nil
        })

      {[%PaymentTransaction{}, %PaymentTransaction{}], 1} =
        Payments.list_charges(%{
          page: 0,
          per_page: 2,
          order: :asc,
          order_by: :status,
          query: "abc"
        })

      {[%PaymentTransaction{status: "ready"}], 1} =
        Payments.list_charges(%{
          page: 0,
          per_page: 2,
          order: :asc,
          order_by: :status,
          query: "welcome"
        })
    end

    test "list_charges/0 returns proper list of payments" do
      insert_list(5, :payment_transaction,
        inserted_at: ~N[2010-01-01 23:00:07],
        status: "ready",
        payment_provider_response: "Some error"
      )

      insert_list(15, :payment_transaction,
        inserted_at: ~N[2000-01-01 23:00:07],
        status: "paid",
        payment_provider_response: "No error"
      )

      payments =
        Payments.list_charges(%{
          page: 7,
          per_page: 2,
          order: :asc,
          order_by: :inserted_at,
          query: nil
        })
        |> elem(0)

      assert List.first(payments).status == "paid"
      assert List.last(payments).status == "ready"

      payments =
        Payments.list_charges(%{
          page: 2,
          per_page: 2,
          order: :asc,
          order_by: :inserted_at,
          query: "Some error"
        })
        |> elem(0)

      assert Enum.count(payments) == 1
      assert List.first(payments).status == "ready"
    end
  end

  describe "get_latest_transfer" do
    test "returns latest transfer from a match" do
      match = insert(:completed_match, payment_transactions: [])

      match = Repo.get(Match, match.id)

      %PaymentTransaction{} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: match,
          inserted_at: ~N[2020-11-21 15:51:55]
        )

      %PaymentTransaction{} =
        insert(:payment_transaction,
          transaction_type: :capture,
          status: "succeeded",
          match: match,
          inserted_at: ~N[2020-11-21 17:41:25]
        )

      %PaymentTransaction{} =
        insert(:payment_transaction,
          transaction_type: :transfer,
          status: "error",
          match: match,
          inserted_at: ~N[2020-11-21 17:41:25]
        )

      %PaymentTransaction{id: latest_transaction_id, match: match} =
        insert(:payment_transaction,
          transaction_type: :transfer,
          status: "succeeded",
          match: match,
          inserted_at: ~N[2020-12-04 20:16:44]
        )

      assert %{id: ^latest_transaction_id} = Payments.get_latest_transfer(match)
    end

    test "sanity_check/3 returns true if new charge does not exceed twice expected amount" do
      match = insert(:completed_match, driver_total_pay: 2000)

      assert true == Payments.sanity_check(match, :driver_total_pay, 1900)
    end

    test "sanity_check/3 returns false if new charge does exceed twice expected amount" do
      match =
        insert(:completed_match,
          driver_total_pay: 2000,
          payment_transactions: [
            insert(:payment_transaction,
              transaction_type: :capture,
              transaction_reason: :charge,
              status: "succeeded",
              match: nil,
              amount: 2000,
              inserted_at: ~N[2020-11-21 17:41:25]
            )
          ]
        )

      assert false == Payments.sanity_check(match, :driver_total_pay, 2000)
    end
  end

  describe "does_not_have_successful_transaction_of_type" do
    test "returns ok if match does not have successful transfer" do
      match = insert(:completed_match)

      %PaymentTransaction{} =
        insert(:payment_transaction,
          transaction_type: :transfer,
          status: "error",
          match: match,
          inserted_at: ~N[2020-11-21 17:41:25]
        )

      assert {:ok, _message} =
               Payments.does_not_have_successful_transaction_of_type(match, :transfer, :charge)
    end

    test "returns ok if match has no transfer transactions" do
      match = insert(:completed_match)

      assert {:ok, _message} =
               Payments.does_not_have_successful_transaction_of_type(match, :transfer, :charge)
    end

    test "returns error if match has successful transfer" do
      match = insert(:completed_match, payment_transactions: [])

      match = Repo.get(Match, match.id)

      %PaymentTransaction{} =
        insert(:payment_transaction,
          transaction_type: :transfer,
          status: "succeeded",
          match: match,
          inserted_at: ~N[2020-11-21 17:41:25]
        )

      assert {:error, _message} =
               Payments.does_not_have_successful_transaction_of_type(match, :transfer, :charge)
    end
  end

  describe "run_cancel_charge/1" do
    test "returns ok if match has cancel charge but no cancel pay for driver" do
      invoiceable_shipper = insert(:shipper_with_location)

      match =
        insert(:completed_match,
          cancel_charge: 2000,
          cancel_charge_driver_pay: 0,
          shipper: invoiceable_shipper
        )

      assert {:ok, _match} = Payments.run_cancel_charge(match)
    end

    test "returns ok if match has driver and cancel pay for driver" do
      invoiceable_shipper = insert(:shipper_with_location)

      match =
        insert(:completed_match,
          cancel_charge: 2000,
          cancel_charge_driver_pay: 1000,
          shipper: invoiceable_shipper
        )

      assert {:ok, _match} = Payments.run_cancel_charge(match)
    end

    test "returns error if match has no driver yet has cancel pay for driver" do
      match =
        insert(:completed_match, driver: nil, cancel_charge: 2000, cancel_charge_driver_pay: 1000)

      assert {:error, "has no driver to transfer pay to"} = Payments.run_cancel_charge(match)
    end

    test "creates PaymentTransaction with :cancel_charge as reason" do
      invoiceable_shipper = insert(:shipper_with_location)

      match =
        insert(:completed_match,
          state: :admin_canceled,
          cancel_charge: 2000,
          cancel_charge_driver_pay: 1000,
          shipper: invoiceable_shipper
        )

      assert {:ok, _} = Payments.run_cancel_charge(match)

      %{payment_transactions: pts} =
        Shipment.get_match(match.id) |> Repo.preload(:payment_transactions)

      assert pts |> Enum.any?(&(&1.transaction_reason == :cancel_charge))
    end
  end

  describe "maybe_charge_with_card" do
    test "returns stripe charge if invoice variables are set" do
      assert {:ok,
              %Stripe.Charge{
                id: stripe_charge_id,
                status: _status,
                amount: _stripe_charge_amount
              }} = Payments.maybe_charge_with_card(1500)

      assert stripe_charge_id != "account_billing"
    end

    test "returns bogus stripe charge with account_billing stripe id if invoice variables are not set" do
      assert {:ok,
              %Stripe.Charge{
                id: "account_billing",
                status: "succeeded",
                amount: 1500
              }} =
               Payments.maybe_charge_with_card(
                 1500,
                 nil,
                 nil
               )
    end

    test "returns bogus stripe charge with account_billing stripe id if one invoice variable is not set" do
      assert {:ok,
              %Stripe.Charge{
                id: "account_billing",
                status: "succeeded",
                amount: 1500
              }} = Payments.maybe_charge_with_card(1500, "cus_12345", nil)
    end
  end

  describe "create_customer/2" do
    test "creates a customer based on a Driver entity with payment_method associated success" do
      driver = insert(:driver)
      assert {:ok, "cus_12345"} = Payments.create_customer(driver, "random_payment_id")
    end

    test "creates a customer based on a Driver entity without payment_method associated success" do
      driver = insert(:driver)
      assert {:ok, "cus_12345"} = Payments.create_customer(driver, nil)
    end

    test "creates a customer based on a Shipper entity with payment_method associated will success" do
      shipper = insert(:shipper)
      assert {:ok, "cus_12345"} = Payments.create_customer(shipper, "random_payment_id")
    end

    test "creates a customer based on a Shipper entity without payment_method associated will success" do
      shipper = insert(:shipper)
      assert {:ok, "cus_12345"} = Payments.create_customer(shipper, nil)
    end

    test "creates a customer based on it email with payment_method associated will success" do
      assert {:ok, "cus_12345"} = Payments.create_customer("test@frayt.com", "random_payment_id")
    end

    test "creates a customer based on it email without payment_method associated will success" do
      assert {:ok, "cus_12345"} = Payments.create_customer("test@frayt.com", nil)
    end

    test "creates a customer based on invalid params will fail" do
      assert {:error, "invalid input"} = Payments.create_customer(%{param: "param"}, "random")
      assert {:error, "invalid input"} = Payments.create_customer(%{param: "param"}, nil)

      assert {:error, "invalid input"} = Payments.create_customer(nil, "random")
      assert {:error, "invalid input"} = Payments.create_customer(nil, nil)
    end
  end

  describe "create_payment_intent/4" do
    test "will fail without amount or invalid currency especified" do
      assert {:error, "An amount is required"} =
               Payments.create_payment_intent("cus_id", "payment_id", nil, "invalid")

      assert {:error, "An amount is required"} =
               Payments.create_payment_intent("cus_id", "payment_id", "", "invalid")

      assert {:error, "A valid currency is required"} =
               Payments.create_payment_intent("cus_id", "payment_id", 3500, "CUR")

      assert {:error, "A valid currency is required"} =
               Payments.create_payment_intent("cus_id", "payment_id", 3500, "")

      assert {:error, "A valid currency is required"} =
               Payments.create_payment_intent("cus_id", "payment_id", 3500, nil)
    end

    test "will succeed in all cases where amount is not null and currency is valid" do
      assert {:ok, %Stripe.PaymentIntent{}} =
               Payments.create_payment_intent("cus_id", "payment_id", 3500, "USD")
    end
  end

  describe "charge_background_check/1" do
    test "will fail with invalid payment_intent_id" do
      driver = insert(:driver)
      intent_id = "random_intent_id"

      assert {:error, "This payment method couldn't be confirmed."} =
               Payments.charge_background_check(driver, %{
                 method_id: nil,
                 intent_id: intent_id
               })

      assert {:error, "This payment method couldn't be confirmed."} =
               Payments.charge_background_check(driver, %{
                 method_id: "",
                 intent_id: intent_id
               })
    end

    test "will succeed with valid payment_intent_id" do
      driver = insert(:driver)
      intent_id = "random_intent_id"
      method_id = "random_method_id"

      %{id: background_check_id} =
        insert(:background_check,
          driver: driver,
          customer_id: "stripe_customer_id",
          transaction_id: intent_id,
          state: :submitted
        )

      charge_response =
        Payments.charge_background_check(driver, %{
          method_id: method_id,
          intent_id: intent_id
        })

      assert {:ok, %Stripe.PaymentIntent{id: ^intent_id},
              %BackgroundCheck{id: ^background_check_id}} = charge_response
    end
  end

  describe "confirm_intent_and_update/2" do
    test "fails when there a background check is not received" do
      assert {:error, "This payment method couldn't be confirmed."} =
               Payments.confirm_intent_and_update("intent_id", nil)
    end

    test "succeed and returns updated background check and payment intent " do
      backgroud_check = insert(:background_check)

      assert {:ok, %Stripe.PaymentIntent{}, %FraytElixir.Screenings.BackgroundCheck{}} =
               Payments.confirm_intent_and_update("intent_id", backgroud_check)
    end
  end
end
