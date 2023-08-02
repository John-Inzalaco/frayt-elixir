defmodule FraytElixir.Repo.Migrations.AddCanceledAtToPaymentTransactions do
  use Ecto.Migration

  def change do
    alter table(:payment_transactions) do
      add :canceled_at, :utc_datetime
    end
  end
end
