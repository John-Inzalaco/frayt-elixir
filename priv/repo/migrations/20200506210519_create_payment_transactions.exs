defmodule FraytElixir.Repo.Migrations.CreatePaymentTransactions do
  use Ecto.Migration

  def change do
    create table(:payment_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string
      add :payment_provider_response, :text
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:payment_transactions, [:match_id])
  end
end
