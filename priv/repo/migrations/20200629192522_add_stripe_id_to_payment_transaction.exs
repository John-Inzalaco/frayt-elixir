defmodule FraytElixir.Repo.Migrations.AddTransactionIdToPaymentTransaction do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      add :stripe_id, :string
    end
  end
end
