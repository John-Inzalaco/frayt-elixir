defmodule FraytElixir.Repo.Migrations.CreateDriverBonusTable do
  use Ecto.Migration

  def change do
    create table(:driver_bonuses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :notes, :string
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)

      add :payment_transaction_id,
          references(:payment_transactions, type: :binary_id, on_delete: :nothing)

      timestamps()
    end
  end
end
