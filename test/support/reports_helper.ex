defmodule FraytElixir.Test.ReportHelper do
  alias FraytElixir.Repo
  alias FraytElixir.Payments.PaymentTransaction
  import FraytElixir.Factory
  import Ecto.Query

  def tedious_setup(
        days_ago,
        amount,
        driver,
        transaction_type \\ :transfer
      ) do
    payment_transaction =
      %PaymentTransaction{id: pt_id, match: match} =
      insert(:payment_transaction,
        transaction_type: transaction_type,
        status: "succeeded",
        driver: driver,
        amount: amount,
        match: insert(:completed_match, driver: driver)
      )

    days_ago = DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600 * days_ago)
    update_query = from pt in PaymentTransaction, where: pt.id == ^pt_id
    Repo.update_all(update_query, set: [inserted_at: days_ago])

    %{payment_transaction: payment_transaction, match: match}
  end
end
