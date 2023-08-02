require Protocol
Protocol.derive(Jason.Encoder, Stripe.Charge)
Protocol.derive(Jason.Encoder, Stripe.Card)
Protocol.derive(Jason.Encoder, Stripe.List)
Protocol.derive(Jason.Encoder, Stripe.Payout)
Protocol.derive(Jason.Encoder, Stripe.Transfer)
Protocol.derive(Jason.Encoder, Stripe.Error)
Protocol.derive(Jason.Encoder, Stripe.Refund)

defmodule FraytElixir.Payments do
  @moduledoc """
  The Payments context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Association.NotLoaded

  alias FraytElixir.Shipment.Match
  alias FraytElixir.Payments.{CreditCard, DriverBonus, PaymentTransaction}
  alias FraytElixir.Accounts.{Shipper, Location, Company, AdminUser}
  alias FraytElixir.{Accounts, PaginationQueryHelpers, Repo}
  alias FraytElixir.Shipment.MatchStateTransition
  alias FraytElixir.Drivers
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Notifications.Slack
  alias FraytElixir.Screenings
  alias FraytElixir.Branch
  alias FraytElixir.Repo

  @config Application.compile_env(:frayt_elixir, __MODULE__, [])

  @payment_provider Keyword.get(
                      @config,
                      :payment_provider,
                      FraytElixir.Payments.StripePaymentProvider
                    )

  @authorize_match Keyword.get(@config, :authorize_match, &FraytElixir.Payments.authorize_match/2)

  @stripe_invoice_customer Keyword.get(@config, :stripe_invoice_customer)
  @stripe_invoice_card Keyword.get(@config, :stripe_invoice_card)

  @doc """
  Gets a single credit_card.

  Raises `Ecto.NoResultsError` if the Credit card does not exist.

  ## Examples

      iex> get_credit_card!(123)
      %CreditCard{}

      iex> get_credit_card!(456)
      ** (Ecto.NoResultsError)

  """
  def get_credit_card!(id), do: Repo.get!(CreditCard, id) |> Repo.preload([:shipper])

  def get_credit_card_for_shipper(%Shipper{} = shipper) do
    credit_card = CreditCard.where_shipper_is(shipper) |> Repo.one() |> Repo.preload(:shipper)
    {:ok, credit_card}
  end

  @doc """
  Creates a credit_card.

  ## Examples

      iex> create_credit_card(%{field: value})
      {:ok, %CreditCard{}}

      iex> create_credit_card(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_credit_card(
        %{
          shipper:
            %Shipper{
              stripe_customer_id: nil
            } = shipper
        } = attrs
      ) do
    with {:ok, stripe_customer_id} <- create_customer(shipper),
         {:ok, updated_shipper} <-
           Accounts.update_shipper_stripe(shipper, %{stripe_customer_id: stripe_customer_id}) do
      create_credit_card(attrs |> Map.put(:shipper, updated_shipper))
    else
      {:error, message} when is_bitstring(message) -> {:error, :card_error, message}
      error -> error
    end
  end

  def create_credit_card(
        %{
          shipper:
            %Shipper{
              stripe_customer_id: stripe_customer_id
            } = shipper,
          stripe_token: stripe_token
        } = attrs
      ) do
    case @payment_provider.create_card(stripe_customer_id, stripe_token) do
      {:ok, last4} ->
        delete_existing_card_for_shipper(shipper)

        attrs =
          attrs
          |> Map.put(:last4, last4)
          |> Map.put(:shipper_id, shipper.id)

        %CreditCard{}
        |> CreditCard.changeset(attrs)
        |> Repo.insert()

      {:error, message} when is_bitstring(message) ->
        {:error, :card_error, message}

      error ->
        error
    end
  end

  def create_customer(shipper_or_driver, payment_method_id \\ nil)

  def create_customer(%Driver{user: %{email: email}}, payment_method_id),
    do: create_customer(email, payment_method_id)

  def create_customer(%Shipper{user: %{email: email}}, payment_method_id),
    do: create_customer(email, payment_method_id)

  def create_customer(customer_email, payment_method_id) when is_binary(customer_email) do
    case @payment_provider.create_customer(customer_email, payment_method_id) do
      {:ok, stripe_customer_id} -> {:ok, stripe_customer_id}
      {:error, message} when is_bitstring(message) -> {:error, :card_error, message}
      error -> {:error, error}
    end
  end

  def create_customer(_customer_email, _payment_method_id) do
    {:error, "invalid input"}
  end

  @doc """
  Deletes a credit_card.

  ## Examples

      iex> delete_credit_card(credit_card)
      {:ok, %CreditCard{}}

      iex> delete_credit_card(credit_card)
      {:error, %Ecto.Changeset{}}

  """
  def delete_credit_card(%CreditCard{} = credit_card) do
    Repo.delete(credit_card)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking credit_card changes.

  ## Examples

      iex> change_credit_card(credit_card)
      %Ecto.Changeset{source: %CreditCard{}}

  """
  def change_credit_card(%CreditCard{} = credit_card) do
    CreditCard.changeset(credit_card, %{})
  end

  defp delete_existing_card_for_shipper(%Shipper{id: shipper_id}) do
    Repo.delete_all(from(cc in CreditCard, where: cc.shipper_id == ^shipper_id))
  end

  def authorize_match(
        %Match{
          shipper: %Shipper{location: %Location{company: %Company{account_billing_enabled: true}}}
        },
        _price
      ) do
    {:ok, "No payment required."}
  end

  def authorize_match(
        %Match{
          shipper: %Shipper{
            stripe_customer_id: _stripe_customer_id,
            credit_card: %NotLoaded{}
          }
        } = match,
        total_price
      ) do
    match |> Repo.preload(shipper: :credit_card) |> authorize_match(total_price)
  end

  def authorize_match(
        %Match{
          shipper: %Shipper{
            stripe_customer_id: stripe_customer_id,
            credit_card: %CreditCard{stripe_card: stripe_card}
          },
          id: match_id
        },
        total_price
      ) do
    with {:ok, %Stripe.Charge{status: status, amount: amount, id: charge_id} = stripe_charge} <-
           @payment_provider.create_charge(%{
             amount: total_price,
             currency: "USD",
             customer: stripe_customer_id,
             source: stripe_card,
             capture: false
           }) do
      %PaymentTransaction{}
      |> PaymentTransaction.changeset(%{
        status: status,
        external_id: charge_id,
        amount: amount,
        transaction_type: :authorize,
        transaction_reason: :charge,
        match_id: match_id,
        payment_provider_response: Jason.encode!(stripe_charge)
      })
      |> Repo.insert()
    end
  end

  def authorize_match(_, _), do: {:error, "Payment is not set up."}

  defp match_charge_field(state, true) when state in [:admin_canceled, :canceled],
    do: :cancel_charge_driver_pay

  defp match_charge_field(state, false) when state in [:admin_canceled, :canceled],
    do: :cancel_charge

  defp match_charge_field(_state, true), do: :driver_total_pay
  defp match_charge_field(_state, false), do: :amount_charged

  def maybe_charge_match_difference(match, field_to_charge)
      when field_to_charge in [:cancel_charge_driver_pay, :cancel_charge] do
    charge_match(match, field_to_charge, :cancel_charge)
  end

  def maybe_charge_match_difference(match, field_to_charge) do
    case does_not_have_successful_transaction_of_type(match, :capture, :charge) do
      {:error, "Match already has a successful transfer transaction"} = error ->
        error

      {:error, _} ->
        recharge_or_refund_custom_amount(match, field_to_charge)

      _ ->
        charge_match(match, field_to_charge, :charge)
    end
  end

  defp recharge_or_refund_custom_amount(match, field_to_charge) do
    current_charge_amount = sum_charged_amount(match)
    new_charge_amount = Map.get(match, field_to_charge)

    case new_charge_amount do
      amount when amount > current_charge_amount ->
        amount_to_charge = amount - current_charge_amount

        case @authorize_match.(match, amount_to_charge) do
          {:ok, %PaymentTransaction{external_id: stripe_charge_id}} ->
            charge_custom_amount(match, amount_to_charge, stripe_charge_id)

          {:ok, "No payment required."} ->
            charge_custom_amount(match, amount_to_charge)

          error ->
            error
        end

      amount when amount < current_charge_amount ->
        amount_to_refund = current_charge_amount - amount
        refund_custom_amount(match, amount_to_refund)

      amount when amount == current_charge_amount ->
        {:ok, "match price has not changed"}
    end
  end

  defp sum_charged_amount(match) do
    list_charges(match.id)
    |> Enum.reduce(0, fn pt, acc ->
      if pt.status == "succeeded" and is_nil(pt.canceled_at) do
        case pt.transaction_type do
          :capture -> acc + pt.amount
          :refund -> acc - pt.amount
          _ -> acc
        end
      else
        acc
      end
    end)
  end

  def sum_driver_paid_amount(match) do
    list_charges(match.id)
    |> Enum.filter(fn charge ->
      charge.driver_id == match.driver_id and
        charge.status == "succeeded" and
        is_nil(charge.canceled_at) and
        charge.transaction_type == :transfer
    end)
    |> Enum.reduce(0, fn pt, acc -> pt.amount + acc end)
  end

  defp refund_custom_amount(
         %Match{
           id: match_id,
           shipper: %Shipper{
             location: %Location{company: %Company{account_billing_enabled: true}}
           }
         },
         amount_to_refund
       ) do
    with invoice_charge <- %Stripe.Charge{
           id: "account_billing",
           status: "succeeded",
           amount: amount_to_refund
         } do
      create_payment_transaction(%{
        status: "succeeded",
        external_id: "account_billing",
        transaction_type: :refund,
        transaction_reason: :charge,
        match_id: match_id,
        amount: amount_to_refund,
        payment_provider_response: Jason.encode!(invoice_charge)
      })
    end
  end

  defp refund_custom_amount(%Match{id: match_id, payment_transactions: pts}, amount_to_refund) do
    with %{external_id: stripe_charge_id} <-
           pts
           |> Enum.filter(&(&1.transaction_type == :capture and &1.status == "succeeded"))
           |> Enum.sort(&(&1.amount > &2.amount))
           |> List.first(),
         {:ok,
          %Stripe.Refund{
            id: stripe_refund_id,
            status: status,
            amount: stripe_refund_amount
          } = stripe_refund_response} <-
           @payment_provider.create_refund(%{
             charge: stripe_charge_id,
             amount: amount_to_refund
           }) do
      create_payment_transaction(%{
        status: status,
        external_id: stripe_refund_id,
        transaction_type: :refund,
        transaction_reason: :charge,
        match_id: match_id,
        amount: stripe_refund_amount,
        payment_provider_response: Jason.encode!(stripe_refund_response)
      })
    end
  end

  def charge_background_check(_driver, %{method_id: _payment_id, intent_id: intent_id}) do
    background_check = Screenings.get_background_check_by_intent_id(intent_id)

    confirm_intent_and_update(intent_id, background_check)
  end

  def charge_background_check(driver, %{method_id: payment_id}) do
    existing_background_checks = Drivers.list_background_checks(driver.id)

    with true <- can_create_new_background_check?(existing_background_checks),
         {:ok, stripe_customer_id} <- create_customer(driver, payment_id),
         {:ok, intent} <-
           create_payment_intent(stripe_customer_id, payment_id, 3500),
         {:ok, background_check} <-
           Screenings.create_background_check(driver.id, stripe_customer_id, intent.id) do
      confirm_intent_and_update(intent.id, background_check)
    end
  end

  defp can_create_new_background_check?(nil), do: true

  defp can_create_new_background_check?(background_checks) do
    background_checks
    |> Enum.any?(&(&1.state in [:pending, :charged, :submitted, :completed]))
    |> case do
      true ->
        {:error,
         "There is an authorization in progress or you have already paid for your background check."}

      _ ->
        true
    end
  end

  def create_payment_intent(customer_id, payment_method_id, amount, currency \\ "USD"),
    do: @payment_provider.create_intent(customer_id, payment_method_id, amount, currency)

  def confirm_intent_and_update(_intent_id, nil) do
    {:error, "This payment method couldn't be confirmed."}
  end

  def confirm_intent_and_update(intent_id, background_check) do
    {state, result} =
      case @payment_provider.confirm_intent(intent_id) do
        {:ok, %{status: :succeeded} = response} -> {:charged, {:ok, response}}
        {:ok, response} -> {:submitted, {:ok, response}}
        {:error, message} -> {:failed, {:error, message}}
      end

    {:ok, background_check} =
      Screenings.update_background_check(background_check, %{
        transaction_id: intent_id,
        state: state
      })

    result
    |> Tuple.append(background_check)
  end

  defp charge_custom_amount(%Match{id: match_id} = match, amount_to_charge) do
    with true <- sanity_check(match, :driver_total_pay, amount_to_charge),
         {:ok,
          %Stripe.Charge{
            id: stripe_charge_id,
            status: status,
            amount: stripe_charge_amount
          } = invoice_charge} <-
           maybe_charge_with_card(amount_to_charge),
         {:ok, payment_transaction} <-
           create_payment_transaction(%{
             status: status,
             external_id: stripe_charge_id,
             transaction_type: :capture,
             transaction_reason: :charge,
             match_id: match_id,
             amount: stripe_charge_amount,
             payment_provider_response: Jason.encode!(invoice_charge)
           }) do
      {:ok, payment_transaction}
    else
      false ->
        {:error, "Fails sanity check and would charge at least double the expected amount"}

      error ->
        error
    end
  end

  defp charge_custom_amount(%Match{id: match_id} = match, amount_to_charge, authorize_stripe_id) do
    with true <- sanity_check(match, :amount_charged, amount_to_charge),
         {:ok,
          %Stripe.Charge{
            id: stripe_charge_id,
            status: status,
            amount: stripe_charge_amount,
            amount_refunded: amount_refunded
          } = stripe_charge} <-
           capture_charge(authorize_stripe_id, amount_to_charge, amount_to_charge),
         {:ok, payment_transaction} <-
           create_payment_transaction(%{
             status: status,
             external_id: stripe_charge_id,
             transaction_type: :capture,
             transaction_reason: :charge,
             match_id: match_id,
             amount: stripe_charge_amount - amount_refunded,
             payment_provider_response: Jason.encode!(stripe_charge)
           }) do
      {:ok, payment_transaction}
    else
      false ->
        {:error, "Fails sanity check and would charge at least double the expected amount"}

      error ->
        error
    end
  end

  def charge_match(%Match{state: state, shipper: shipper} = match) do
    match =
      Repo.preload(match, payment_transactions: [:driver_bonus], shipper: [location: :company])

    case shipper do
      %{location: %Location{company: %Company{account_billing_enabled: true}}} ->
        maybe_charge_match_difference(match, match_charge_field(state, true))

      _ ->
        maybe_charge_match_difference(match, match_charge_field(state, false))
    end
  end

  def charge_match(
        %Match{
          id: match_id,
          shipper: %Shipper{location: %Location{company: %Company{account_billing_enabled: true}}}
        } = match,
        field_to_charge,
        reason_to_charge
      ) do
    driver_pay = Map.get(match, field_to_charge)

    with true <- sanity_check(match, field_to_charge, driver_pay),
         {:ok,
          %Stripe.Charge{
            id: stripe_charge_id,
            status: status,
            amount: stripe_charge_amount
          } = invoice_charge} <- maybe_charge_with_card(driver_pay),
         {:ok, payment_transaction} <-
           create_payment_transaction(%{
             status: status,
             external_id: stripe_charge_id,
             transaction_type: :capture,
             transaction_reason: reason_to_charge,
             match_id: match_id,
             amount: stripe_charge_amount,
             payment_provider_response: Jason.encode!(invoice_charge)
           }) do
      {:ok, payment_transaction}
    else
      false ->
        {:error, "Fails sanity check and would charge at least double the expected amount"}

      {:error, %Stripe.Error{} = error} ->
        log_error(match, error, :capture, :charge, driver_pay)
    end
  end

  def charge_match(
        %Match{
          payment_transactions: payment_transactions,
          id: match_id
        } = match,
        field_to_charge,
        reason_to_charge
      ) do
    amount_to_be_captured = Map.get(match, field_to_charge)

    with payment_transaction = %PaymentTransaction{
           amount: authorized_amount
         } <-
           find_authorize_transaction(payment_transactions),
         true <- sanity_check(match, field_to_charge, amount_to_be_captured),
         %PaymentTransaction{external_id: stripe_charge_id} <-
           maybe_reauthorize_stripe_charge(
             payment_transaction,
             match,
             amount_to_be_captured,
             authorized_amount
           ),
         {:ok,
          %Stripe.Charge{
            id: stripe_charge_id,
            status: status,
            amount: stripe_charge_amount,
            amount_refunded: amount_refunded
          } = stripe_charge} <-
           capture_charge(stripe_charge_id, amount_to_be_captured, authorized_amount),
         {:ok, payment_transaction} <-
           create_payment_transaction(%{
             status: status,
             external_id: stripe_charge_id,
             transaction_type: :capture,
             transaction_reason: reason_to_charge,
             match_id: match_id,
             amount: stripe_charge_amount - amount_refunded,
             payment_provider_response: Jason.encode!(stripe_charge)
           }) do
      {:ok, payment_transaction}
    else
      nil ->
        {:error, "No prior authorize transaction"}

      false ->
        {:error, "Fails sanity check and would charge at least double the expected amount"}

      {:error, %Stripe.Error{} = error} ->
        log_error(match, error, :capture, :charge, amount_to_be_captured)
    end
  end

  def capture_charge(stripe_charge_id, amount_to_be_captured, authorized_amount) do
    if amount_to_be_captured < authorized_amount do
      @payment_provider.capture_charge(stripe_charge_id, amount_to_be_captured)
    else
      @payment_provider.capture_charge(stripe_charge_id)
    end
  end

  def cancel_payment_transaction(payment_transaction) do
    PaymentTransaction.changeset(payment_transaction, %{canceled_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def maybe_reauthorize_stripe_charge(payment_transaction, match, amount, authorized_amount)
      when amount > authorized_amount do
    with {:ok, %PaymentTransaction{canceled_at: %DateTime{}}} <-
           cancel_payment_transaction(payment_transaction),
         {:ok, %PaymentTransaction{} = payment_transaction} <-
           @authorize_match.(match, amount) do
      payment_transaction
    end
  end

  def maybe_reauthorize_stripe_charge(payment_transaction, _match, amount, authorized_amount)
      when amount <= authorized_amount,
      do: payment_transaction

  def transfer_driver_bonus(%{
        driver:
          %Driver{
            id: driver_id
          } = driver,
        amount: bonus_amount,
        notes: notes,
        match: match,
        admin_user: %AdminUser{id: admin_user_id}
      }) do
    Repo.transaction(fn ->
      bonus =
        create_driver_bonus(%{
          driver_id: driver_id,
          notes: notes,
          created_by_id: admin_user_id
        })

      {:ok, transaction} =
        create_disbursement(driver, match, bonus_amount, "driver bonus", bonus.id, :driver_bonus)

      update_driver_bonus(bonus, %{payment_transaction_id: transaction.id})
    end)
  end

  def transfer_driver_pay(%Match{payment_transactions: %NotLoaded{}} = match),
    do: match |> Repo.preload(payment_transactions: [:driver_bonus]) |> transfer_driver_pay()

  def transfer_driver_pay(%Match{driver: %NotLoaded{}} = match),
    do: match |> Repo.preload(:driver) |> transfer_driver_pay()

  def transfer_driver_pay(%Match{state: :completed} = match),
    do: transfer_driver_pay(match, :driver_total_pay, :charge)

  def transfer_driver_pay(%Match{state: state} = match)
      when state in [:admin_canceled, :canceled],
      do: transfer_driver_pay(match, :cancel_charge_driver_pay, :cancel_charge)

  def transfer_driver_pay(match, field_to_transfer, reason) do
    %Match{driver: driver} = match
    driver_total_pay = Map.get(match, field_to_transfer)
    current_driver_paid = sum_driver_paid_amount(match)
    amount_to_disburse = driver_total_pay - current_driver_paid

    have_successful_transaction =
      does_not_have_successful_transaction_of_type(match, :transfer, reason)

    successful_transactions? =
      case have_successful_transaction do
        {:ok, _} -> false
        _ -> true
      end

    is_recharging? = have_mst_from_to?(:charged, :completed)

    if successful_transactions? and is_recharging? and amount_to_disburse > 0 do
      if driver_total_pay < current_driver_paid do
        {:error, "The driver transfers cannot be decreased."}
      else
        create_disbursement(driver, match, amount_to_disburse, "driver payout", match.id, reason)
      end
    else
      with {:ok, _} <- have_successful_transaction do
        create_disbursement(driver, match, driver_total_pay, "driver payout", match.id, reason)
      end
    end
  end

  def create_wallet(%Driver{address_id: nil}), do: {:error, :missing_address}

  def create_wallet(%Driver{} = driver) do
    case Branch.create_wallet(driver) do
      {:ok, %{"status" => wallet_state}} ->
        Drivers.update_driver_wallet(driver, wallet_state)

      {:error, _code, %{"error" => error, "message" => message}} ->
        {:error, "#{error}: #{message}"}

      {:error, _code, response} ->
        {:error, inspect(response)}

      {:error, error} ->
        {:error, HTTPoison.Error.message(error)}
    end
  end

  def list_charges,
    do:
      Repo.all(PaymentTransaction)
      |> Repo.preload(
        driver_bonus: [],
        driver: [],
        match: [:coupon, :origin_address, :shipper, match_stops: :destination_address]
      )

  def list_charges(%{query: query} = args),
    do:
      PaymentTransaction
      |> PaymentTransaction.filter_by_query(query)
      |> PaginationQueryHelpers.list_record(args,
        driver_bonus: [],
        driver: [],
        match: [:coupon, shipper: [location: :company]]
      )

  def list_charges(match_id) do
    PaymentTransaction
    |> PaymentTransaction.where_match_is(match_id)
    |> order_by(asc: :inserted_at)
    |> Repo.all()
    |> Repo.preload([:driver_bonus, :driver, match: :shipper])
  end

  def does_not_have_successful_transaction_of_type(%Match{} = match, type, reason) do
    match = Repo.preload(match, payment_transactions: [:driver_bonus])

    successful_transactions =
      match.payment_transactions
      |> Enum.filter(&filter_transactions(&1, type, reason))
      |> Enum.count()

    if successful_transactions > 0 do
      {:error, "Match already has a successful #{type} transaction"}
    else
      {:ok, match}
    end
  end

  def have_mst_from_to?(from_state, to_state) do
    qry =
      from mst in MatchStateTransition,
        where: mst.from == ^from_state and mst.to == ^to_state

    transaction = Repo.all(qry)

    not Enum.empty?(transaction)
  end

  def sanity_check(match, field_to_charge, nil),
    do: sanity_check(match, field_to_charge, 0)

  def sanity_check(%Match{state: state} = match, field_to_charge, amount_to_charge)
      when state in [:canceled, :admin_canceled],
      do: sanity_check(match, field_to_charge, amount_to_charge, :cancel_charge)

  def sanity_check(match, field_to_charge, amount_to_charge),
    do: sanity_check(match, field_to_charge, amount_to_charge, :charge)

  def sanity_check(
        %Match{shortcode: shortcode} = match,
        field_to_charge,
        amount_to_charge,
        transaction_reason
      ) do
    expected_total_charge_amount = Map.get(match, field_to_charge)

    expected_total_charge_amount =
      if expected_total_charge_amount |> is_nil(), do: 0, else: expected_total_charge_amount

    %{payment_transactions: pts} = match |> Repo.preload(:payment_transactions)

    current_charge_amount =
      pts
      |> Enum.filter(
        &(&1.transaction_reason == transaction_reason and
            &1.transaction_type in [:capture, :refund] and
            is_nil(&1.canceled_at))
      )
      |> Enum.reduce(
        0,
        &if(&1.transaction_type == :capture and &1.transaction_reason == transaction_reason,
          do: &2 + &1.amount,
          else: &2 - &1.amount
        )
      )

    if current_charge_amount + amount_to_charge >= expected_total_charge_amount * 2 and
         expected_total_charge_amount != 0 do
      Slack.send_payment_message(
        match,
        "failed to capture payment for ##{shortcode} because the charge would exceed twice the expected amount",
        :danger
      )

      false
    else
      true
    end
  end

  defp filter_transactions(
         transaction,
         type,
         :all
       ),
       do:
         transaction.transaction_type == type and transaction.status == "succeeded" and
           is_nil(transaction.driver_bonus)

  defp filter_transactions(transaction, type, reason),
    do:
      transaction.transaction_reason == reason and transaction.transaction_type == type and
        transaction.status == "succeeded" and is_nil(transaction.driver_bonus)

  def get_latest_transfer(%Match{payment_transactions: %NotLoaded{}} = match),
    do: match |> Repo.preload(payment_transactions: [:driver_bonus]) |> get_latest_transfer()

  def get_latest_transfer(match) do
    get_latest_payment_transaction_from_match_by_type(match, :transfer)
  end

  def get_latest_capture(%Match{payment_transactions: %NotLoaded{}} = match),
    do: match |> Repo.preload(payment_transactions: [:driver_bonus]) |> get_latest_capture()

  def get_latest_capture(match) do
    get_latest_payment_transaction_from_match_by_type(match, :capture)
  end

  def get_all_transfers(%Match{payment_transactions: %NotLoaded{}} = match),
    do: match |> Repo.preload(payment_transactions: [:driver_bonus]) |> get_all_transfers()

  def get_all_transfers(match) do
    get_payment_transactions_from_match_by_type(match, :transfer)
  end

  def get_all_captures(%Match{payment_transactions: %NotLoaded{}} = match),
    do: match |> Repo.preload(payment_transactions: [:driver_bonus]) |> get_all_captures()

  def get_all_captures(match) do
    get_payment_transactions_from_match_by_type(match, :capture)
  end

  def get_all_authorizes(%Match{payment_transactions: %NotLoaded{}} = match),
    do: match |> Repo.preload(payment_transactions: [:driver_bonus]) |> get_all_captures()

  def get_all_authorizes(match) do
    get_payment_transactions_from_match_by_type(match, :authorize)
  end

  def maybe_charge_with_card(driver_pay),
    do: maybe_charge_with_card(driver_pay, @stripe_invoice_customer, @stripe_invoice_card)

  def maybe_charge_with_card(driver_pay, customer, card)
      when not is_nil(customer) and not is_nil(card) do
    @payment_provider.create_charge(%{
      amount: driver_pay,
      customer: customer,
      source: card,
      currency: "USD",
      capture: true
    })
  end

  def maybe_charge_with_card(driver_pay, _, _) do
    {:ok,
     %Stripe.Charge{
       id: "account_billing",
       status: "succeeded",
       amount: driver_pay
     }}
  end

  defp get_latest_payment_transaction_from_match_by_type(
         match,
         type
       ) do
    match
    |> get_payment_transactions_from_match_by_type(type)
    |> Enum.filter(&is_nil(&1.driver_bonus))
    |> List.first()
  end

  defp get_payment_transactions_from_match_by_type(
         %Match{payment_transactions: payment_transactions},
         type
       ) do
    payment_transactions
    |> Enum.sort(&(Date.compare(&1.inserted_at, &2.inserted_at) == :gt))
    |> Enum.filter(&(&1.transaction_type == type))
  end

  def run_cancel_charge(%Match{cancel_charge_driver_pay: cancel_pay, driver: nil})
      when not is_nil(cancel_pay) and cancel_pay > 0,
      do: {:error, "has no driver to transfer pay to"}

  def run_cancel_charge(%Match{} = match),
    do: charge_match(match)

  def find_authorize_transaction(payment_transactions) do
    payment_transactions
    |> Enum.find(
      &(&1.status == "succeeded" && &1.transaction_type == :authorize && is_nil(&1.canceled_at))
    )
  end

  defp create_payment_transaction(attrs) do
    %PaymentTransaction{}
    |> PaymentTransaction.changeset(attrs)
    |> Repo.insert()
  end

  defp create_disbursement(nil, match, _amount, description, _external_id, reason),
    do: send_error(nil, description, "MISSING DRIVER", reason, nil, match)

  defp create_disbursement(driver, match, amount, description, external_id, reason) do
    match_id = match && match.id

    with {:ok, payment_transaction} <-
           create_payment_transaction(%{
             status: "pending",
             transaction_type: :transfer,
             transaction_reason: reason,
             match_id: match_id,
             driver_id: driver.id,
             external_id: external_id,
             amount: amount
           }) do
      description =
        case match do
          %Match{shortcode: shortcode} -> "#{description} for Match ##{shortcode}"
          _ -> description
        end

      case Branch.create_disbursement(driver, %{
             amount: amount,
             external_id: external_id,
             description: description
           }) do
        {:ok, %{"status" => status} = response} when status in ["COMPLETED", "succeeded"] ->
          update_payment_transaction(payment_transaction, %{
            status: "succeeded",
            payment_provider_response: Jason.encode!(response)
          })

        {:ok, %{"status" => status, "status_reason" => reason} = response} ->
          send_error(
            payment_transaction,
            description,
            status,
            reason,
            Jason.encode!(response),
            match
          )

        {:error, _code, response} ->
          send_error(
            payment_transaction,
            description,
            "Error",
            inspect(response),
            inspect(response),
            match
          )

        {:error, error} ->
          send_error(
            payment_transaction,
            description,
            "Network error",
            HTTPoison.Error.message(error),
            nil,
            match
          )
      end
    end
  end

  defp send_error(payment_transaction, description, status, reason, response, match) do
    if match do
      Slack.send_payment_message(
        match,
        "failed to transfer payment for #{description}. #{status}: #{reason}",
        :danger
      )
    end

    with false <- is_nil(payment_transaction),
         {:ok, payment_transaction} <-
           update_payment_transaction(payment_transaction, %{
             status: "error",
             payment_provider_response: response
           }) do
      {:error, payment_transaction}
    else
      true -> {:error, "No payment transaction created"}
    end
  end

  defp update_payment_transaction(payment_transaction, attrs) do
    payment_transaction
    |> PaymentTransaction.changeset(attrs)
    |> Repo.update()
  end

  defp create_driver_bonus(attrs) do
    %DriverBonus{}
    |> DriverBonus.changeset(attrs)
    |> Repo.insert!()
  end

  defp update_driver_bonus(bonus, attrs) do
    bonus
    |> DriverBonus.changeset(attrs)
    |> Repo.update!()
  end

  defp log_error(
         %Match{id: match_id} = match,
         %Stripe.Error{request_id: request_id, message: message} = error,
         transaction_type,
         transaction_reason,
         amount
       ) do
    request_id =
      case request_id do
        {"Request-Id", result} -> result
        result -> result
      end

    {:ok, pt} =
      create_payment_transaction(%{
        status: "error",
        match_id: match_id,
        external_id: request_id,
        notes: message,
        amount: amount,
        transaction_type: transaction_type,
        transaction_reason: transaction_reason,
        payment_provider_response: inspect(error)
      })

    Slack.send_payment_message(
      match,
      "failed to #{Atom.to_string(transaction_type)} payment. Reason: #{message}",
      transaction_type_message_level(transaction_type)
    )

    {:error, pt}
  end

  defp transaction_type_message_level(:transfer), do: :danger

  defp transaction_type_message_level(:capture), do: :warning
end
