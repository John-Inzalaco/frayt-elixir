defmodule FraytElixir.Repo.Migrations.ModifyTransactionReasonToDefaultToCharge do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      modify :transaction_reason, :string, default: "charge"
    end
  end
end
