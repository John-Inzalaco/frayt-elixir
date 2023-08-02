defmodule FraytElixir.Test.FakeStripe do
  @stripe_intent %Stripe.PaymentIntent{
    id: "pi_1Dse262eZvKYlo2CNAdNOxmG_secret_NZZIsaijpKLMNobPMGOZa0D8W",
    amount: 5000,
    client_secret: "client_secret",
    confirmation_method: :manual,
    currency: "USD",
    customer: nil,
    status: :succeeded
  }
  def create_customer(_email, _payment_method), do: {:ok, "cus_12345"}

  def create_card(_, "used token"),
    do: {:error, "Hey moron you can't use a token more than once."}

  def create_card(_, "garbage"), do: {:error, "No such token."}
  def create_card(_, _), do: {:ok, "4242"}

  def create_intent(_, _, nil, _), do: {:error, "An amount is required"}
  def create_intent(_, _, "", _), do: {:error, "An amount is required"}

  def create_intent(_, _, _, "CUR"), do: {:error, "A valid currency is required"}
  def create_intent(_, _, _, ""), do: {:error, "A valid currency is required"}
  def create_intent(_, _, _, nil), do: {:error, "A valid currency is required"}

  def create_intent(customer, _, amount, currency) do
    {:ok,
     Map.merge(@stripe_intent, %{
       amount: amount,
       currency: currency,
       customer: customer
     })}
  end

  def confirm_intent(intent_id) do
    {:ok, Map.merge(@stripe_intent, %{id: intent_id})}
  end

  def create_charge(%{source: "bad_card"}) do
    error = %Stripe.Error{
      code: :card_error,
      extra: %{
        card_code: :card_declined,
        charge_id: "ch_1Gi0NNBC59DOQgALmpZsfsk0",
        decline_code: "generic_decline",
        http_status: 402,
        raw_error: %{
          "charge" => "ch_1Gi0NNBC59DOQgALmpZsfsk0",
          "code" => "card_declined",
          "decline_code" => "generic_decline",
          "doc_url" => "https://stripe.com/docs/error-codes/card-declined",
          "message" => "Your card was declined.",
          "type" => "card_error"
        }
      },
      message: "Your card was declined.",
      request_id: nil,
      source: :stripe,
      user_message: "Your card was declined."
    }

    {:error, error}
  end

  def create_charge(%{amount: 777}) do
    error = %Stripe.Error{
      code: :card_error,
      extra: %{
        card_code: :card_declined,
        charge_id: "ch_1Gi0NNBC59DOQgALmpZsfsk0",
        decline_code: "generic_decline",
        http_status: 402,
        raw_error: %{
          "charge" => "ch_1Gi0NNBC59DOQgALmpZsfsk0",
          "code" => "card_declined",
          "decline_code" => "generic_decline",
          "doc_url" => "https://stripe.com/docs/error-codes/card-declined",
          "message" => "Your card was declined.",
          "type" => "card_error"
        }
      },
      message: "Your card was declined.",
      request_id: nil,
      source: :stripe,
      user_message: "Your card was declined."
    }

    {:error, error}
  end

  def create_charge(%{amount: amount, customer: customer, source: source}) do
    {:ok,
     %Stripe.Charge{
       metadata: %{},
       livemode: false,
       application: nil,
       status: "succeeded",
       receipt_url:
         "https://pay.stripe.com/receipts/acct_1AZmtwBC59DOQgAL/ch_1GgFP5BC59DOQgAL8YctupgX/rcpt_HEiqN5c3xo4OJrkeZOg39lwFFeTJc4a",
       payment_method: source,
       order: nil,
       failure_message: nil,
       created: 1_588_879_747,
       description: nil,
       transfer_data: nil,
       outcome: %{
         network_status: "approved_by_network",
         reason: nil,
         risk_level: "normal",
         risk_score: 0,
         seller_message: "Payment complete.",
         type: "authorized"
       },
       statement_descriptor: nil,
       statement_descriptor_suffix: nil,
       payment_intent: nil,
       application_fee: nil,
       customer: customer,
       transfer_group: nil,
       receipt_email: nil,
       refunded: false,
       dispute: nil,
       amount_refunded: 0,
       payment_method_details: %{
         card: %{
           brand: "visa",
           checks: %{
             address_line1_check: nil,
             address_postal_code_check: "pass",
             cvc_check: "pass"
           },
           country: "US",
           exp_month: 10,
           exp_year: 2025,
           fingerprint: "ys7wVeIVLV3ZMNUn",
           funding: "credit",
           installments: nil,
           last4: "4242",
           network: "visa",
           three_d_secure: nil,
           wallet: nil
         },
         type: "card"
       },
       id: "stripe_id_expected_amount_#{amount}",
       paid: true,
       object: "charge",
       application_fee_amount: nil,
       transfer: nil,
       source_transfer: nil,
       currency: "usd",
       shipping: nil,
       balance_transaction: "txn_1GgFP5BC59DOQgALgf4mvpRS",
       on_behalf_of: nil,
       fraud_details: %{},
       review: nil,
       receipt_number: nil,
       captured: false,
       failure_code: nil,
       refunds: %Stripe.List{
         data: [],
         has_more: false,
         object: "list",
         total_count: 0,
         url: "/v1/charges/ch_1GgFP5BC59DOQgAL8YctupgX/refunds"
       },
       amount: amount,
       billing_details: %{
         address: %{
           city: nil,
           country: nil,
           line1: nil,
           line2: nil,
           postal_code: "45231",
           state: nil
         },
         email: nil,
         name: "undefined undefined",
         phone: nil
       },
       source: %Stripe.Card{
         account: nil,
         address_city: nil,
         address_country: nil,
         address_line1: nil,
         address_line1_check: nil,
         address_line2: nil,
         address_state: nil,
         address_zip: "45231",
         address_zip_check: "pass",
         available_payout_methods: nil,
         brand: "Visa",
         country: "US",
         currency: nil,
         customer: customer,
         cvc_check: "pass",
         default_for_currency: nil,
         deleted: nil,
         dynamic_last4: nil,
         exp_month: 10,
         exp_year: 2025,
         fingerprint: "ys7wVeIVLV3ZMNUn",
         funding: "credit",
         id: source,
         last4: "4242",
         metadata: %{},
         name: "undefined undefined",
         object: "card",
         recipient: nil,
         tokenization_method: nil
       },
       invoice: nil
     }}
  end

  def create_charge(%{amount: amount}),
    do:
      create_charge(%{
        amount: amount,
        customer: "cus_HEimbKMycDQulK",
        source: "card_1GgFLBBC59DOQgALb9TgqUQv"
      })

  def capture_charge(_, new_amount) do
    amount_refunded = 1999
    charge_amount = new_amount + amount_refunded

    {:ok,
     %Stripe.Charge{
       receipt_url:
         "https://pay.stripe.com/receipts/acct_1AZmtwBC59DOQgAL/ch_1HHZG1BC59DOQgALhJ6P3KIo/rcpt_HrHpDFj143Nqn5dWGIiKLiV1bS8TLVW",
       application_fee_amount: nil,
       status: "succeeded",
       order: nil,
       transfer_data: nil,
       description: nil,
       receipt_number: nil,
       receipt_email: nil,
       amount: charge_amount,
       captured: true,
       dispute: nil,
       failure_code: nil,
       billing_details: %{
         address: %{
           city: nil,
           country: nil,
           line1: nil,
           line2: nil,
           postal_code: "45231",
           state: nil
         },
         email: nil,
         name: "undefined undefined",
         phone: nil
       },
       object: "charge",
       livemode: false,
       currency: "usd",
       payment_method_details: %{
         card: %{
           brand: "visa",
           checks: %{
             address_line1_check: nil,
             address_postal_code_check: "pass",
             cvc_check: nil
           },
           country: "US",
           exp_month: 5,
           exp_year: 2023,
           fingerprint: "35Ojc5fQyqrhr5n8",
           funding: "credit",
           installments: nil,
           last4: "1111",
           network: "visa",
           three_d_secure: nil,
           wallet: nil
         },
         type: "card"
       },
       balance_transaction: "txn_1HHZIRBC59DOQgAL9DHtRMzR",
       source: %Stripe.Card{
         account: nil,
         address_city: nil,
         address_country: nil,
         address_line1: nil,
         address_line1_check: nil,
         address_line2: nil,
         address_state: nil,
         address_zip: "45231",
         address_zip_check: "pass",
         available_payout_methods: nil,
         brand: "Visa",
         country: "US",
         currency: nil,
         customer: "cus_HrGLCM5f2wsrYK",
         cvc_check: nil,
         default_for_currency: nil,
         deleted: nil,
         dynamic_last4: nil,
         exp_month: 5,
         exp_year: 2023,
         fingerprint: "35Ojc5fQyqrhr5n8",
         funding: "credit",
         id: "card_1HHXonBC59DOQgALf2FfSIjO",
         last4: "1111",
         metadata: %{},
         name: "undefined undefined",
         object: "card",
         recipient: nil,
         tokenization_method: nil
       },
       fraud_details: %{},
       statement_descriptor: nil,
       payment_intent: nil,
       application_fee: nil,
       id: "ch_1HHZG1BC59DOQgALhJ6P3KIo",
       review: nil,
       invoice: nil,
       shipping: nil,
       on_behalf_of: nil,
       refunded: false,
       failure_message: nil,
       payment_method: "card_1HHXonBC59DOQgALf2FfSIjO",
       refunds: %Stripe.List{
         data: [
           %Stripe.Refund{
             amount: amount_refunded,
             balance_transaction: "txn_1HHZIRBC59DOQgALjUMITyLM",
             charge: "ch_1HHZG1BC59DOQgALhJ6P3KIo",
             created: 1_597_774_351,
             currency: "usd",
             failure_balance_transaction: nil,
             failure_reason: nil,
             id: "re_1HHZIRBC59DOQgAL0aX5aZzx",
             metadata: %{},
             object: "refund",
             payment: nil,
             reason: nil,
             receipt_number: nil,
             source_transfer_reversal: nil,
             status: "succeeded",
             transfer_reversal: nil
           }
         ],
         has_more: false,
         object: "list",
         total_count: 1,
         url: "/v1/charges/ch_1HHZG1BC59DOQgALhJ6P3KIo/refunds"
       },
       amount_refunded: amount_refunded,
       statement_descriptor_suffix: nil,
       outcome: %{
         network_status: "approved_by_network",
         reason: nil,
         risk_level: "normal",
         risk_score: 12,
         seller_message: "Payment complete.",
         type: "authorized"
       },
       metadata: %{},
       transfer_group: nil,
       customer: "cus_HrGLCM5f2wsrYK",
       application: nil,
       created: 1_597_774_201,
       paid: true,
       transfer: nil,
       source_transfer: nil
     }}
  end

  def capture_charge("fradulent"),
    do:
      {:error,
       %Stripe.Error{
         code: :card_error,
         extra: %{
           card_code: :card_declined,
           charge_id: "ch_1Gi0NNBC59DOQgALmpZsfsk0",
           decline_code: "fradulent",
           http_status: 402,
           raw_error: %{
             "charge" => "ch_1Gi0NNBC59DOQgALmpZsfsk0",
             "code" => "card_declined",
             "decline_code" => "fradulent",
             "doc_url" => "https://stripe.com/docs/error-codes/card-declined",
             "message" => "Your card was declined.",
             "type" => "card_error"
           }
         },
         message: "Your card was declined.",
         request_id: nil,
         source: :stripe,
         user_message: "Your card was declined."
       }}

  def capture_charge("garbage"),
    do:
      {:error,
       %Stripe.Error{
         code: :invalid_request_error,
         extra: %{
           card_code: :resource_missing,
           http_status: 404,
           param: :charge,
           raw_error: %{
             "code" => "resource_missing",
             "doc_url" => "https://stripe.com/docs/error-codes/resource-missing",
             "message" => "No such charge: garbage",
             "param" => "charge",
             "type" => "invalid_request_error"
           }
         },
         message: "No such charge: garbage",
         request_id: nil,
         source: :stripe,
         user_message: nil
       }}

  def capture_charge("stripe_id_expected_amount_" <> amount) do
    {:ok,
     %Stripe.Charge{
       metadata: %{},
       livemode: false,
       application: nil,
       status: "succeeded",
       receipt_url:
         "https://pay.stripe.com/receipts/acct_1AZmtwBC59DOQgAL/ch_1GgFP5BC59DOQgAL8YctupgX/rcpt_HEiqN5c3xo4OJrkeZOg39lwFFeTJc4a",
       payment_method: "card_1GgFLBBC59DOQgALb9TgqUQv",
       order: nil,
       failure_message: nil,
       created: 1_588_879_747,
       description: nil,
       transfer_data: nil,
       outcome: %{
         network_status: "approved_by_network",
         reason: nil,
         risk_level: "normal",
         risk_score: 0,
         seller_message: "Payment complete.",
         type: "authorized"
       },
       statement_descriptor: nil,
       statement_descriptor_suffix: nil,
       payment_intent: nil,
       application_fee: nil,
       customer: "cus_HEimbKMycDQulK",
       transfer_group: nil,
       receipt_email: nil,
       refunded: false,
       dispute: nil,
       amount_refunded: 0,
       payment_method_details: %{
         card: %{
           brand: "visa",
           checks: %{
             address_line1_check: nil,
             address_postal_code_check: "pass",
             cvc_check: "pass"
           },
           country: "US",
           exp_month: 10,
           exp_year: 2025,
           fingerprint: "ys7wVeIVLV3ZMNUn",
           funding: "credit",
           installments: nil,
           last4: "4242",
           network: "visa",
           three_d_secure: nil,
           wallet: nil
         },
         type: "card"
       },
       id: "ch_1GgFP5BC59DOQgAL8YctupgX",
       paid: true,
       object: "charge",
       application_fee_amount: nil,
       transfer: nil,
       source_transfer: nil,
       currency: "usd",
       shipping: nil,
       balance_transaction: "txn_1GgFP5BC59DOQgALgf4mvpRS",
       on_behalf_of: nil,
       fraud_details: %{},
       review: nil,
       receipt_number: nil,
       captured: true,
       failure_code: nil,
       refunds: %Stripe.List{
         data: [],
         has_more: false,
         object: "list",
         total_count: 0,
         url: "/v1/charges/ch_1GgFP5BC59DOQgAL8YctupgX/refunds"
       },
       amount: String.to_integer(amount),
       billing_details: %{
         address: %{
           city: nil,
           country: nil,
           line1: nil,
           line2: nil,
           postal_code: "45231",
           state: nil
         },
         email: nil,
         name: "undefined undefined",
         phone: nil
       },
       source: %Stripe.Card{
         account: nil,
         address_city: nil,
         address_country: nil,
         address_line1: nil,
         address_line1_check: nil,
         address_line2: nil,
         address_state: nil,
         address_zip: "45231",
         address_zip_check: "pass",
         available_payout_methods: nil,
         brand: "Visa",
         country: "US",
         currency: nil,
         customer: "cus_HEimbKMycDQulK",
         cvc_check: "pass",
         default_for_currency: nil,
         deleted: nil,
         dynamic_last4: nil,
         exp_month: 10,
         exp_year: 2025,
         fingerprint: "ys7wVeIVLV3ZMNUn",
         funding: "credit",
         id: "card_1GgFLBBC59DOQgALb9TgqUQv",
         last4: "4242",
         metadata: %{},
         name: "undefined undefined",
         object: "card",
         recipient: nil,
         tokenization_method: nil
       },
       invoice: nil
     }}
  end

  def capture_charge(stripe_id) when is_binary(stripe_id) do
    {:ok,
     %Stripe.Charge{
       metadata: %{},
       livemode: false,
       application: nil,
       status: "succeeded",
       receipt_url:
         "https://pay.stripe.com/receipts/acct_1AZmtwBC59DOQgAL/ch_1GgFP5BC59DOQgAL8YctupgX/rcpt_HEiqN5c3xo4OJrkeZOg39lwFFeTJc4a",
       payment_method: "card_1GgFLBBC59DOQgALb9TgqUQv",
       order: nil,
       failure_message: nil,
       created: 1_588_879_747,
       description: nil,
       transfer_data: nil,
       outcome: %{
         network_status: "approved_by_network",
         reason: nil,
         risk_level: "normal",
         risk_score: 0,
         seller_message: "Payment complete.",
         type: "authorized"
       },
       statement_descriptor: nil,
       statement_descriptor_suffix: nil,
       payment_intent: nil,
       application_fee: nil,
       customer: "cus_HEimbKMycDQulK",
       transfer_group: nil,
       receipt_email: nil,
       refunded: false,
       dispute: nil,
       amount_refunded: 0,
       payment_method_details: %{
         card: %{
           brand: "visa",
           checks: %{
             address_line1_check: nil,
             address_postal_code_check: "pass",
             cvc_check: "pass"
           },
           country: "US",
           exp_month: 10,
           exp_year: 2025,
           fingerprint: "ys7wVeIVLV3ZMNUn",
           funding: "credit",
           installments: nil,
           last4: "4242",
           network: "visa",
           three_d_secure: nil,
           wallet: nil
         },
         type: "card"
       },
       id: "ch_1GgFP5BC59DOQgAL8YctupgX",
       paid: true,
       object: "charge",
       application_fee_amount: nil,
       transfer: nil,
       source_transfer: nil,
       currency: "usd",
       shipping: nil,
       balance_transaction: "txn_1GgFP5BC59DOQgALgf4mvpRS",
       on_behalf_of: nil,
       fraud_details: %{},
       review: nil,
       receipt_number: nil,
       captured: true,
       failure_code: nil,
       refunds: %Stripe.List{
         data: [],
         has_more: false,
         object: "list",
         total_count: 0,
         url: "/v1/charges/ch_1GgFP5BC59DOQgAL8YctupgX/refunds"
       },
       amount: 2000,
       billing_details: %{
         address: %{
           city: nil,
           country: nil,
           line1: nil,
           line2: nil,
           postal_code: "45231",
           state: nil
         },
         email: nil,
         name: "undefined undefined",
         phone: nil
       },
       source: %Stripe.Card{
         account: nil,
         address_city: nil,
         address_country: nil,
         address_line1: nil,
         address_line1_check: nil,
         address_line2: nil,
         address_state: nil,
         address_zip: "45231",
         address_zip_check: "pass",
         available_payout_methods: nil,
         brand: "Visa",
         country: "US",
         currency: nil,
         customer: "cus_HEimbKMycDQulK",
         cvc_check: "pass",
         default_for_currency: nil,
         deleted: nil,
         dynamic_last4: nil,
         exp_month: 10,
         exp_year: 2025,
         fingerprint: "ys7wVeIVLV3ZMNUn",
         funding: "credit",
         id: "card_1GgFLBBC59DOQgALb9TgqUQv",
         last4: "4242",
         metadata: %{},
         name: "undefined undefined",
         object: "card",
         recipient: nil,
         tokenization_method: nil
       },
       invoice: nil
     }}
  end

  def create_seller(%{individual: %{address: %{country: "United States"}}}) do
    {:error,
     %Stripe.Error{
       code: :invalid_request_error,
       extra: %{
         http_status: 400,
         param: :"individual[address][country]",
         raw_error: %{
           "message" =>
             "Country 'United States' is unknown. Try using a 2-character alphanumeric country code instead, such as 'US', 'EG', or 'GB'. A full list of country codes is available at https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements",
           "param" => "individual[address][country]",
           "type" => "invalid_request_error"
         }
       },
       message:
         "Country 'United States' is unknown. Try using a 2-character alphanumeric country code instead, such as 'US', 'EG', or 'GB'. A full list of country codes is available at https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements",
       request_id: nil,
       source: :stripe,
       user_message: nil
     }}
  end

  def create_seller(_) do
    {:ok, "acct_53u9402ut4"}
  end

  def create_refund(%{amount: amount}) do
    {:ok,
     %Stripe.Refund{
       id: "re_3K6hEw2eZvKYlo2C144WoqEw",
       object: "refund",
       amount: amount,
       balance_transaction: nil,
       charge: "ch_3K6hEw2eZvKYlo2C15E5NMdE",
       created: 1_639_512_286,
       currency: "usd",
       metadata: %{},
       reason: nil,
       receipt_number: nil,
       source_transfer_reversal: nil,
       status: "succeeded",
       transfer_reversal: nil
     }}
  end

  def create_refund(stripe_id) when is_binary(stripe_id) do
    {:ok,
     %Stripe.Refund{
       id: "re_3K6hEw2eZvKYlo2C144WoqEw",
       object: "refund",
       amount: 100,
       balance_transaction: nil,
       charge: "ch_3K6hEw2eZvKYlo2C15E5NMdE",
       created: 1_639_512_286,
       currency: "usd",
       metadata: %{},
       reason: nil,
       receipt_number: nil,
       source_transfer_reversal: nil,
       status: "succeeded",
       transfer_reversal: nil
     }}
  end

  def create_payout(%{amount: amount}, connect_account: _) when amount > 9999,
    do:
      {:error,
       %Stripe.Error{
         code: :invalid_request_error,
         extra: %{
           card_code: :balance_insufficient,
           http_status: 400,
           raw_error: %{
             "code" => "balance_insufficient",
             "doc_url" => "https://stripe.com/docs/error-codes/balance-insufficient",
             "message" =>
               "You have insufficient funds in your Stripe account for this transfer. Your card balance is too low.  You can use the /v1/balance endpoint to view your Stripe balance (for more details, see stripe.com/docs/api#balance).",
             "type" => "invalid_request_error"
           }
         },
         message:
           "You have insufficient funds in your Stripe account for this transfer. Your card balance is too low.  You can use the /v1/balance endpoint to view your Stripe balance (for more details, see stripe.com/docs/api#balance).",
         request_id: nil,
         source: :stripe,
         user_message: nil
       }}

  def create_payout(%{amount: amount, destination: destination}, connect_account: _connect_account) do
    {:ok,
     %Stripe.Payout{
       amount: amount,
       arrival_date: 1_593_561_600,
       automatic: false,
       balance_transaction: "txn_1Gzr18LzXE3HCGGNu7A1t22z",
       created: 1_593_552_566,
       currency: "usd",
       deleted: nil,
       description: nil,
       destination: destination,
       failure_balance_transaction: nil,
       failure_code: nil,
       failure_message: nil,
       id: "po_1Gzr18LzXE3HCGGN03RNdbI8",
       livemode: false,
       metadata: %{},
       method: "standard",
       object: "payout",
       source_type: "card",
       statement_descriptor: nil,
       status: "pending",
       type: "bank_account"
     }}
  end

  def create_transfer(%{destination: "not_transfer_capable"}),
    do:
      {:error,
       %Stripe.Error{
         code: :invalid_request_error,
         extra: %{
           http_status: 400,
           raw_error: %{
             "message" =>
               "Your destination account needs to have at least one of the following capabilities enabled: transfers, legacy_payments",
             "type" => "invalid_request_error"
           }
         },
         message:
           "Your destination account needs to have at least one of the following capabilities enabled: transfers, legacy_payments",
         request_id: nil,
         source: :stripe,
         user_message: nil
       }}

  def create_transfer(%{
        amount: amount,
        destination: destination
      }) do
    {:ok,
     %Stripe.Transfer{
       amount: amount,
       amount_reversed: 0,
       balance_transaction: "txn_1Gzqr1BC59DOQgAL6ScyUWkS",
       created: 1_593_551_939,
       currency: "usd",
       description: nil,
       destination: destination,
       destination_payment: "py_1Gzqr1LzXE3HCGGNX410CAvs",
       id: "tr_1Gzqr1BC59DOQgALZF4mZwEA",
       livemode: false,
       metadata: %{},
       object: "transfer",
       reversals: %Stripe.List{
         data: [],
         has_more: false,
         object: "list",
         total_count: 0,
         url: "/v1/transfers/tr_1Gzqr1BC59DOQgALZF4mZwEA/reversals"
       },
       reversed: false,
       source_type: "card",
       transfer_group: nil
     }}
  end

  def update_account(%Stripe.Account{} = _stripe_account, _attrs) do
    {:ok,
     %Stripe.Account{
       business_profile: %{
         mcc: "4214",
         name: "Burt Macklin",
         product_description: nil,
         support_address: nil,
         support_email: "email-cef03235@example.com",
         support_phone: "4532245102",
         support_url: nil,
         url: "frayt.app/driver_id"
       },
       business_type: "individual",
       capabilities: %{card_payments: "inactive", transfers: "inactive"},
       charges_enabled: false,
       company: %{
         address: %{
           city: "Cincinnati",
           country: "US",
           line1: "708 Walnut Street",
           line2: nil,
           postal_code: "45202",
           state: "Ohio"
         },
         directors_provided: true,
         executives_provided: true,
         name: nil,
         owners_provided: true,
         phone: "+14532245102",
         tax_id_provided: false,
         verification: %{
           document: %{back: nil, details: nil, details_code: nil, front: nil}
         }
       },
       country: "US",
       created: 1_597_788_620,
       default_currency: "usd",
       details_submitted: false,
       email: "email-cef03235@example.com",
       external_accounts: %Stripe.List{
         data: [],
         has_more: false,
         object: "list",
         total_count: 0,
         url: "/v1/accounts/acct_1HHd0ZGVkA6LJVEO/external_accounts"
       },
       id: "acct_1HHd0ZGVkA6LJVEO",
       individual: %Stripe.Person{
         account: "acct_1HHd0ZGVkA6LJVEO",
         address: %{
           city: "Cincinnati",
           country: "US",
           line1: "708 Walnut Street",
           line2: nil,
           postal_code: "45202",
           state: "Ohio"
         },
         address_kana: nil,
         address_kanji: nil,
         created: 1_597_788_620,
         dob: %{day: 1, month: 1, year: 1901},
         email: "email-cef03235@example.com",
         first_name: "Burt",
         first_name_kana: nil,
         first_name_kanji: nil,
         gender: nil,
         id: "person_HrLhWltS16obez",
         id_number_provided: false,
         last_name: "Macklin",
         last_name_kana: nil,
         last_name_kanji: nil,
         metadata: %{},
         object: "person",
         phone: "+14532245102",
         relationship: %{
           director: false,
           executive: false,
           owner: false,
           percent_ownership: nil,
           representative: true,
           title: nil
         },
         requirements: %{
           currently_due: ["id_number"],
           errors: [],
           eventually_due: ["id_number"],
           past_due: ["id_number"],
           pending_verification: []
         },
         ssn_last_4_provided: true,
         verification: %{
           additional_document: %{
             back: nil,
             details: nil,
             details_code: nil,
             front: nil
           },
           details: "Provided identity information could not be verified",
           details_code: "failed_keyed_identity",
           document: %{back: nil, details: nil, details_code: nil, front: nil},
           status: "unverified"
         }
       },
       metadata: %{},
       object: "account",
       payouts_enabled: false,
       requirements: %{
         current_deadline: nil,
         currently_due: ["external_account", "individual.id_number"],
         disabled_reason: "requirements.past_due",
         errors: [],
         eventually_due: ["external_account", "individual.id_number"],
         past_due: ["external_account", "individual.id_number"],
         pending_verification: []
       },
       settings: %{
         bacs_debit_payments: %{},
         branding: %{icon: nil, logo: nil, primary_color: nil, secondary_color: nil},
         card_payments: %{
           decline_on: %{avs_failure: false, cvc_failure: false},
           statement_descriptor_prefix: nil
         },
         dashboard: %{display_name: "frayt.app", timezone: "Etc/UTC"},
         payments: %{
           statement_descriptor: "FRAYT.APP",
           statement_descriptor_kana: nil,
           statement_descriptor_kanji: nil
         },
         payouts: %{
           debit_negative_balances: false,
           schedule: %{delay_days: 2, interval: "manual"},
           statement_descriptor: nil
         }
       },
       tos_acceptance: %{date: 1_597_788_619, ip: "127.0.0.1", user_agent: "Lynx 0.1"},
       type: "custom"
     }}
  end

  def update_account("garbage", _),
    do:
      {:error,
       %Stripe.Error{
         code: :invalid_request_error,
         extra: %{
           card_code: :account_invalid,
           http_status: 403,
           raw_error: %{
             "code" => "account_invalid",
             "doc_url" => "https://stripe.com/docs/error-codes/account-invalid",
             "message" =>
               "The provided key 'sk_test_Zi******************unOz' does not have access to account 'garbage' (or that account does not exist). Application access may have been revoked.",
             "type" => "invalid_request_error"
           }
         },
         message:
           "The provided key 'sk_test_Zi******************unOz' does not have access to account 'garbage' (or that account does not exist). Application access may have been revoked.",
         request_id: nil,
         source: :stripe,
         user_message: nil
       }}

  def update_account(_id, _attrs),
    do:
      {:ok,
       %Stripe.Account{
         business_profile: %{
           mcc: "4214",
           name: "Burt Macklin",
           product_description: nil,
           support_address: nil,
           support_email: "email-cef03235@example.com",
           support_phone: "4532245102",
           support_url: nil,
           url: "frayt.app/driver_id"
         },
         business_type: "individual",
         capabilities: %{card_payments: "inactive", transfers: "inactive"},
         charges_enabled: false,
         company: %{
           address: %{
             city: "Cincinnati",
             country: "US",
             line1: "708 Walnut Street",
             line2: nil,
             postal_code: "45202",
             state: "Ohio"
           },
           directors_provided: true,
           executives_provided: true,
           name: nil,
           owners_provided: true,
           phone: "+14532245102",
           tax_id_provided: false,
           verification: %{
             document: %{back: nil, details: nil, details_code: nil, front: nil}
           }
         },
         country: "US",
         created: 1_597_788_620,
         default_currency: "usd",
         details_submitted: false,
         email: "email-cef03235@example.com",
         external_accounts: %Stripe.List{
           data: [],
           has_more: false,
           object: "list",
           total_count: 0,
           url: "/v1/accounts/acct_1HHd0ZGVkA6LJVEO/external_accounts"
         },
         id: "acct_1HHd0ZGVkA6LJVEO",
         individual: %Stripe.Person{
           account: "acct_1HHd0ZGVkA6LJVEO",
           address: %{
             city: "Cincinnati",
             country: "US",
             line1: "708 Walnut Street",
             line2: nil,
             postal_code: "45202",
             state: "Ohio"
           },
           address_kana: nil,
           address_kanji: nil,
           created: 1_597_788_620,
           dob: %{day: 1, month: 1, year: 1901},
           email: "email-cef03235@example.com",
           first_name: "Burt",
           first_name_kana: nil,
           first_name_kanji: nil,
           gender: nil,
           id: "person_HrLhWltS16obez",
           id_number_provided: false,
           last_name: "Macklin",
           last_name_kana: nil,
           last_name_kanji: nil,
           metadata: %{},
           object: "person",
           phone: "+14532245102",
           relationship: %{
             director: false,
             executive: false,
             owner: false,
             percent_ownership: nil,
             representative: true,
             title: nil
           },
           requirements: %{
             currently_due: ["id_number"],
             errors: [],
             eventually_due: ["id_number"],
             past_due: ["id_number"],
             pending_verification: []
           },
           ssn_last_4_provided: true,
           verification: %{
             additional_document: %{
               back: nil,
               details: nil,
               details_code: nil,
               front: nil
             },
             details: "Provided identity information could not be verified",
             details_code: "failed_keyed_identity",
             document: %{back: nil, details: nil, details_code: nil, front: nil},
             status: "unverified"
           }
         },
         metadata: %{},
         object: "account",
         payouts_enabled: false,
         requirements: %{
           current_deadline: nil,
           currently_due: ["external_account", "individual.id_number"],
           disabled_reason: "requirements.past_due",
           errors: [],
           eventually_due: ["external_account", "individual.id_number"],
           past_due: ["external_account", "individual.id_number"],
           pending_verification: []
         },
         settings: %{
           bacs_debit_payments: %{},
           branding: %{icon: nil, logo: nil, primary_color: nil, secondary_color: nil},
           card_payments: %{
             decline_on: %{avs_failure: false, cvc_failure: false},
             statement_descriptor_prefix: nil
           },
           dashboard: %{display_name: "frayt.app", timezone: "Etc/UTC"},
           payments: %{
             statement_descriptor: "FRAYT.APP",
             statement_descriptor_kana: nil,
             statement_descriptor_kanji: nil
           },
           payouts: %{
             debit_negative_balances: false,
             schedule: %{delay_days: 2, interval: "manual"},
             statement_descriptor: nil
           }
         },
         tos_acceptance: %{date: 1_597_788_619, ip: "127.0.0.1", user_agent: "Lynx 0.1"},
         type: "custom"
       }}
end
