defmodule FraytElixir.Repo.Migrations.AddTransactionReasonToPaymentTransaction do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      add :transaction_reason, :string
    end
  end
end
