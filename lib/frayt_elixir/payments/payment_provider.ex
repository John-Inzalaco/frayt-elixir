defmodule FraytElixir.Payments.StripePaymentProvider do
  def create_customer(email, nil) do
    case Stripe.Customer.create(%{email: email}) do
      {:ok, %Stripe.Customer{id: stripe_customer_id}} -> {:ok, stripe_customer_id}
      {:error, %Stripe.Error{message: message}} -> {:error, message}
    end
  end

  def create_customer(email, payment_method_id) do
    case Stripe.Customer.create(%{email: email, payment_method: payment_method_id}) do
      {:ok, %Stripe.Customer{id: stripe_customer_id}} -> {:ok, stripe_customer_id}
      {:error, %Stripe.Error{message: message}} -> {:error, message}
    end
  end

  def create_card(customer_id, token) do
    case Stripe.Card.create(%{customer: customer_id, source: token}) do
      {:ok, %Stripe.Card{last4: last4}} -> {:ok, last4}
      {:error, %Stripe.Error{message: message}} -> {:error, message}
    end
  end

  def create_charge(charge_attrs) do
    case Stripe.Charge.create(charge_attrs) do
      {:ok, %Stripe.Charge{} = charge} -> {:ok, charge}
      {:error, %Stripe.Error{} = error} -> {:error, error}
    end
  end

  def create_intent(customer_id, payment_method_id, amount, currency) do
    intent_params = %{
      :customer => customer_id,
      :payment_method => payment_method_id,
      :amount => amount,
      :currency => currency,
      :confirmation_method => :manual
    }

    case Stripe.PaymentIntent.create(intent_params) do
      {:ok, intent} -> {:ok, intent}
      {:error, %Stripe.Error{message: message}} -> {:error, message}
    end
  end

  def confirm_intent(intent_id) do
    case Stripe.PaymentIntent.confirm(intent_id, %{}) do
      {:ok, intent} -> {:ok, intent}
      {:error, %Stripe.Error{message: message}} -> {:error, message}
    end
  end

  def capture_charge(stripe_id) do
    case Stripe.Charge.capture(stripe_id, %{}) do
      {:ok, %Stripe.Charge{} = charge} -> {:ok, charge}
      {:error, %Stripe.Error{} = error} -> {:error, error}
    end
  end

  def capture_charge(stripe_id, new_amount) do
    case Stripe.Charge.capture(stripe_id, %{amount: new_amount}) do
      {:ok, %Stripe.Charge{} = charge} -> {:ok, charge}
      {:error, %Stripe.Error{} = error} -> {:error, error}
    end
  end

  def create_refund(refund_attrs) do
    case Stripe.Refund.create(refund_attrs) do
      {:ok, %Stripe.Refund{} = refund} -> {:ok, refund}
      {:error, %Stripe.Error{} = error} -> {:error, error}
    end
  end

  def update_account(account_id, attrs), do: Stripe.Account.update(account_id, attrs)
end
