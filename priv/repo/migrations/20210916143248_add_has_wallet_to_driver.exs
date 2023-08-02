defmodule FraytElixir.Repo.Migrations.MigrateSellersToWallets do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :has_wallet, :boolean
    end

    alter table(:payment_transactions) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
    end

    execute &migrate_from_seller/0
  end

  defp migrate_from_seller do
    repo().query!("""
    update payment_transactions
    set driver_id = d.id
    from drivers as d
    where d.seller_account_id = payment_transactions.seller_account_id
    """)
  end
end
