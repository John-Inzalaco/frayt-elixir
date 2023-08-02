defmodule FraytElixir.Repo.Migrations.UpdateTransactionReasonToCorrectReason do
  use Ecto.Migration
  alias FraytElixir.Repo
  import Ecto.Query

  def change do
    update_charge_payments()
    update_driver_bonus_payments()
  end

  defp update_charge_payments do
    from(p in "payment_transactions",
      join: m in "matches",
      on: p.match_id == m.id,
      update: [
        set: [
          transaction_reason:
            fragment(
              "CASE WHEN (? IS NOT NULL) THEN 'cancel_charge' ELSE 'charge' END",
              m.cancel_charge
            )
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp update_driver_bonus_payments do
    from(p in "payment_transactions",
      join: bonus in "driver_bonuses",
      on: p.id == bonus.payment_transaction_id,
      update: [
        set: [
          transaction_reason: "driver_bonus"
        ]
      ]
    )
    |> Repo.update_all([])
  end
end
