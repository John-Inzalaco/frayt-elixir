defmodule FraytElixir.Repo.Migrations.CreateSellerAccounts do
  use Ecto.Migration

  def change do
    create table(:seller_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_account_id, :string
      add :stripe_bank_id, :string
      add :stripe_bank_last_4, :string

      timestamps()
    end

    alter table(:drivers) do
      add :seller_account_id, references(:seller_accounts, type: :binary_id, on_delete: :nothing)
    end

    create index(:drivers, [:seller_account_id])
  end
end
