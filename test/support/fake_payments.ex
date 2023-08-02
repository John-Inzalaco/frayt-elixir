defmodule FraytElixir.Test.FakePayments do
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Repo

  def authorize_match(
        %Match{id: match_id},
        total_price
      ) do
    %PaymentTransaction{}
    |> PaymentTransaction.changeset(%{
      status: "succeeded",
      external_id: "stripe_id_expected_amount_#{total_price}",
      amount: total_price,
      transaction_type: :authorize,
      transaction_reason: :charge,
      match_id: match_id,
      payment_provider_response: Jason.encode!(%{})
    })
    |> Repo.insert()
  end
end
