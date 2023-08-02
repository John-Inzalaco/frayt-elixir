defmodule FraytElixir.Repo.Migrations.AddTypeToPaymentTransaction do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      add :transaction_type, :string
    end
  end
end
