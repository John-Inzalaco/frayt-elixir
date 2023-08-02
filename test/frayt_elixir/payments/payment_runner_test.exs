defmodule FraytElixir.Payments.PaymentRunnerTest do
  use FraytElixir.DataCase
  import FraytElixir.Factory

  alias FraytElixir.Payments
  alias FraytElixir.Workers.PaymentRunner
  alias FraytElixir.Shipment

  describe "run_payment_transactions/1" do
    test "sets match to charged only if both capture and transfer succeeds" do
      match = insert(:completed_match)

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: match
      )

      PaymentRunner.run_payment_transactions(match)

      assert %{state: :completed} = Shipment.get_match(match.id)
    end
  end

  describe "retrieve_completed_matches/1" do
    test "ignores completed matches older than 7 days" do
      recent_match_cutoff = Timex.now() |> Timex.shift(days: -7)
      outdated_match = recent_match_cutoff |> Timex.shift(days: -2)

      insert(:completed_match_state_transition,
        match: build(:completed_match, shortcode: "RECENT1")
      )

      insert(:completed_match_state_transition,
        inserted_at: outdated_match
      )

      assert [%{shortcode: "RECENT1"}] =
               PaymentRunner.retrieve_completed_matches(recent_match_cutoff)
    end
  end

  describe "retrieve_canceled_matches/1" do
    test "ignores canceled matches older than 7 days" do
      recent_match_cutoff = Timex.now() |> Timex.shift(days: -7)
      outdated_match = recent_match_cutoff |> Timex.shift(days: -2)

      insert(:match_state_transition,
        from: :accepted,
        to: :canceled,
        match: build(:canceled_match, shortcode: "NOCHARGE")
      )

      insert(:match_state_transition,
        from: :accepted,
        to: :canceled,
        match: build(:canceled_match, cancel_charge: 1250, shortcode: "RECENT1")
      )

      insert(:match_state_transition,
        from: :accepted,
        to: :canceled,
        inserted_at: outdated_match,
        match: build(:canceled_match, cancel_charge: 1250, shortcode: "OLD1")
      )

      assert [%{shortcode: "RECENT1"}] =
               PaymentRunner.retrieve_canceled_matches(recent_match_cutoff)
    end
  end

  describe "run_capture/1" do
    test "succeeds if match hasn't captured the charge" do
      driver = insert(:driver_with_wallet)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver, amount_charged: 2000)
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: uncharged_match
      )

      assert {:ok, "Successfully charged"} == PaymentRunner.run_capture(uncharged_match)
    end

    test "succeeds if match has already captured the charge" do
      driver = insert(:driver_with_wallet)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver, amount_charged: 2000)
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: uncharged_match
      )

      {:ok, _} = Payments.charge_match(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert {:ok, "match price has not changed"} == PaymentRunner.run_capture(charged_match)
    end

    test "succeeds with account billing if match has already captured the charge" do
      driver = insert(:driver_with_wallet)
      invoiceable_shipper = insert(:shipper_with_location)

      uncharged_match =
        insert(:match,
          state: :completed,
          driver: driver,
          driver_total_pay: 2000,
          shipper: invoiceable_shipper
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: uncharged_match
      )

      {:ok, _} = Payments.charge_match(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert {:ok, "match price has not changed"} == PaymentRunner.run_capture(charged_match)

      %{payment_transactions: pts} =
        Shipment.get_match(charged_match.id)
        |> Repo.preload(:payment_transactions)

      assert pts |> Enum.count() == 1
    end

    test "succeeds if match pricing was adjusted" do
      driver = insert(:driver_with_wallet)

      match_stop = insert(:match_stop, has_load_fee: true, index: 0)
      # invoiceable_shipper = insert(:shipper_with_location)

      initial_amount = 2696 + 1999

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          external_id: "stripe_id_expected_amount_#{initial_amount}",
          status: "succeeded",
          amount: initial_amount,
          match:
            build(:match,
              state: :completed,
              driver: driver,
              # shipper: invoiceable_shipper,
              amount_charged: initial_amount,
              fees: [
                build(:match_fee, type: :base_fee, amount: 2696),
                build(:match_fee, type: :load_fee, amount: 1999)
              ],
              match_stops: [match_stop]
            )
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: uncharged_match
      )

      PaymentRunner.run_capture(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      {:ok, updated_match} =
        FraytElixir.Matches.update_match(charged_match, %{
          match_stops: [
            %{
              id: match_stop.id,
              has_load_fee: false
            }
          ],
          state: :completed
        })

      assert {:ok, "Successfully charged"} == PaymentRunner.run_capture(updated_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert charged_match.payment_transactions
             |> Enum.any?(
               &(&1.transaction_type == :refund and &1.transaction_reason == :charge and
                   &1.amount == 811)
             )
    end
  end

  describe "has_not_exceeded_limit/2" do
    test "is true if the amount of failed charges is less than the limit" do
      match = insert(:completed_match, payment_transactions: [])

      insert(:payment_transaction,
        transaction_type: :authorize,
        external_id: "garbage",
        status: "succeeded",
        match: match
      )

      insert(:payment_transaction,
        transaction_type: :capture,
        external_id: "garbage",
        match: match
      )

      updated_match = Shipment.get_match(match.id)

      assert true == PaymentRunner.has_not_exceeded_limit?(updated_match, :capture)
    end

    test "is false if the amount of failed charges is over the limit" do
      match = insert(:completed_match, payment_transactions: [])

      insert(:payment_transaction,
        transaction_type: :authorize,
        external_id: "garbage",
        status: "succeeded",
        match: match
      )

      insert_list(3, :payment_transaction,
        transaction_type: :capture,
        external_id: "garbage",
        match: match
      )

      updated_match = Shipment.get_match(match.id)

      assert {:error, "exceeded limit of failed attempts"} ==
               PaymentRunner.has_not_exceeded_limit?(updated_match, :capture)
    end
  end

  describe "run_transfer/1" do
    test "succeeds if match hasn't already transferred payment and 12 hours have elapsed" do
      driver = insert(:driver_with_wallet)
      thirteen_hours_ago = Timex.now() |> Timex.shift(hours: -13)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver, amount_charged: 2000)
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: uncharged_match,
        inserted_at: thirteen_hours_ago
      )

      {:ok, _} = Payments.charge_match(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert true == PaymentRunner.run_transfer(charged_match)
    end

    test "fails if 12 hours have not yet elapsed since completion" do
      driver = insert(:driver_with_wallet)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver, amount_charged: 2000)
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: uncharged_match
      )

      {:ok, _} = Payments.charge_match(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert false == PaymentRunner.run_transfer(charged_match)
    end

    test "fails if transfer does not succeed" do
      driver = insert(:driver, wallet_state: nil)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          external_id: "garbage",
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver)
        )

      %{match: charged_match} =
        insert(:payment_transaction,
          transaction_type: :capture,
          external_id: "garbage",
          status: "succeeded",
          match: uncharged_match
        )

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: charged_match
      )

      assert false == PaymentRunner.run_transfer(charged_match)
    end

    test "ignores driver bonuses" do
      driver = insert(:driver_with_wallet)
      admin_user = insert(:admin_user)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match: build(:match, state: :completed, driver: driver, amount_charged: 2000)
        )

      Payments.transfer_driver_bonus(%{
        driver: driver,
        amount: 1200,
        notes: nil,
        match: uncharged_match,
        admin_user: admin_user
      })

      match_with_bonus = Shipment.get_match(uncharged_match.id)

      thirteen_hours_ago = Timex.now() |> Timex.shift(hours: -13)

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: match_with_bonus,
        inserted_at: thirteen_hours_ago
      )

      {:ok, _} = Payments.charge_match(match_with_bonus)
      charged_match = Shipment.get_match(match_with_bonus.id)

      assert true == PaymentRunner.run_transfer(charged_match)
    end
  end

  describe "run_cancel_charge/1" do
    test "succeeds if match hasn't captured the charge" do
      driver = insert(:driver_with_wallet)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          transaction_reason: :cancel_charge,
          status: "succeeded",
          match: build(:match, state: :accepted, driver: driver, amount_charged: 2000)
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: uncharged_match
      )

      assert {:ok, "Successfully charged"} == PaymentRunner.run_cancel_charge(uncharged_match)
    end

    test "succeeds if match has already captured the charge" do
      driver = insert(:driver_with_wallet)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          transaction_reason: :cancel_charge,
          status: "succeeded",
          match: build(:match, state: :accepted, driver: driver, amount_charged: 2000)
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: uncharged_match
      )

      {:ok, _} = Payments.charge_match(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert {:ok, "match price has not changed"} ==
               PaymentRunner.run_cancel_charge(charged_match)
    end

    test "succeeds with account billing if match has already captured the charge" do
      driver = insert(:driver_with_wallet)
      invoiceable_shipper = insert(:shipper_with_location)

      uncharged_match =
        insert(:match,
          state: :accepted,
          driver: driver,
          driver_total_pay: 2000,
          shipper: invoiceable_shipper
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: uncharged_match
      )

      {:ok, _} = Payments.charge_match(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert {:ok, "match price has not changed"} ==
               PaymentRunner.run_cancel_charge(charged_match)

      %{payment_transactions: pts} =
        Shipment.get_match(charged_match.id)
        |> Repo.preload(:payment_transactions)

      assert pts |> Enum.count() == 1
    end

    test "fails if cancel charge was adjusted" do
      driver = insert(:driver_with_wallet)

      initial_amount = 2696 + 1999

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          transaction_reason: :cancel_charge,
          external_id: "stripe_id_expected_amount_#{initial_amount}",
          status: "succeeded",
          amount: initial_amount,
          match:
            build(:match,
              state: :admin_canceled,
              driver: driver,
              cancel_charge: initial_amount,
              cancel_charge_driver_pay: floor(initial_amount * 0.5),
              amount_charged: initial_amount
            )
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: uncharged_match
      )

      PaymentRunner.run_cancel_charge(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      {:ok, updated_match} =
        FraytElixir.Matches.update_match(charged_match, %{
          cancel_charge: floor(initial_amount * 0.8),
          state: :admin_canceled
        })

      adjusted_match = Shipment.get_match(updated_match.id)

      assert {:ok, "Match already has a successful capture transaction"} ==
               PaymentRunner.run_cancel_charge(adjusted_match)
    end
  end

  describe "run_cancel_transfer/1" do
    test "succeeds if match hasn't already transferred cancel payment and 12 hours have elapsed" do
      driver = insert(:driver_with_wallet)
      thirteen_hours_ago = Timex.now() |> Timex.shift(hours: -13)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_reason: :cancel_charge,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              state: :admin_canceled,
              driver: driver,
              cancel_charge: 2000,
              cancel_charge_driver_pay: 1000
            )
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: uncharged_match,
        inserted_at: thirteen_hours_ago
      )

      {:ok, _} = Payments.run_cancel_charge(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert true == PaymentRunner.run_cancel_transfer(charged_match)
    end

    test "fails if 12 hours have not yet elapsed since completion" do
      driver = insert(:driver_with_wallet)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_reason: :cancel_charge,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              state: :admin_canceled,
              driver: driver,
              cancel_charge: 2000,
              cancel_charge_driver_pay: 1000
            )
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: uncharged_match
      )

      {:ok, _} = Payments.run_cancel_charge(uncharged_match)
      charged_match = Shipment.get_match(uncharged_match.id)

      assert false == PaymentRunner.run_cancel_transfer(charged_match)
    end

    test "fails if transfer does not succeed" do
      driver = insert(:driver, wallet_state: nil)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_type: :authorize,
          transaction_reason: :cancel_charge,
          external_id: "garbage",
          status: "succeeded",
          match: build(:match, state: :admin_canceled, driver: driver)
        )

      %{match: charged_match} =
        insert(:payment_transaction,
          transaction_type: :capture,
          transaction_reason: :cancel_charge,
          external_id: "garbage",
          status: "succeeded",
          match: uncharged_match
        )

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: charged_match
      )

      assert false == PaymentRunner.run_cancel_transfer(charged_match)
    end

    test "ignores driver bonuses" do
      driver = insert(:driver_with_wallet)
      admin_user = insert(:admin_user)
      thirteen_hours_ago = Timex.now() |> Timex.shift(hours: -13)

      %{match: uncharged_match} =
        insert(:payment_transaction,
          transaction_reason: :cancel_charge,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              state: :admin_canceled,
              driver: driver,
              cancel_charge: 2000,
              cancel_charge_driver_pay: 1000
            )
        )

      Payments.transfer_driver_bonus(%{
        driver: driver,
        amount: 1200,
        notes: nil,
        match: uncharged_match,
        admin_user: admin_user
      })

      match_with_bonus = Shipment.get_match(uncharged_match.id)

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: match_with_bonus,
        inserted_at: thirteen_hours_ago
      )

      {:ok, _} = Payments.run_cancel_charge(match_with_bonus)
      charged_match = Shipment.get_match(match_with_bonus.id)

      assert true == PaymentRunner.run_cancel_transfer(charged_match)
    end
  end

  describe "recent_match?/2" do
    test "returns true if match was delivered within 7 days" do
      match = insert(:match)

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: match
      )

      assert true == PaymentRunner.recent_match?(match, [:completed, "completed"])
    end

    test "returns true if latest completed state was within 7 days" do
      match = insert(:match)

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: match
      )

      eight_days_ago = Timex.now() |> Timex.shift(days: -8)

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: match,
        inserted_at: eight_days_ago
      )

      assert true == PaymentRunner.recent_match?(match, [:completed, "completed"])
    end

    test "returns false if match was delivered more than 7 days ago" do
      match = insert(:match)
      eight_days_ago = Timex.now() |> Timex.shift(days: -8)

      insert(:match_state_transition,
        from: :delivered,
        to: :completed,
        match: match,
        inserted_at: eight_days_ago
      )

      assert false == PaymentRunner.recent_match?(match, [:completed, "completed"])
    end

    test "returns true if canceled match was canceled within 7 days" do
      match = insert(:match)

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: match
      )

      assert true ==
               PaymentRunner.recent_match?(match, [
                 :admin_canceled,
                 "admin_canceled",
                 :canceled,
                 "canceled"
               ])
    end

    test "returns false if canceled match was canceled more than 7 days ago" do
      match = insert(:match)
      eight_days_ago = Timex.now() |> Timex.shift(days: -8)

      insert(:match_state_transition,
        from: :accepted,
        to: :admin_canceled,
        match: match,
        inserted_at: eight_days_ago
      )

      assert false ==
               PaymentRunner.recent_match?(match, [
                 :admin_canceled,
                 "admin_canceled",
                 :canceled,
                 "canceled"
               ])
    end
  end
end
