defmodule FraytElixir.Repo.Migrations.AddOldTransactionIdToPaymentTransactions do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      add :old_transaction_id, :text
    end
  end
end
