defmodule FraytElixir.Repo.Migrations.AddIndexesToMatchesTable do
  use Ecto.Migration

  def change do
    create index(:matches, [:driver_id])
    create index(:matches, [:shipper_id])
    create index(:matches, [:network_operator_id])
    create index(:matches, [:schedule_id])
    create index(:matches, [:delivery_batch_id])
    create index(:matches, [:origin_address_id])
    create index(:matches, [:state])

    create index(:vehicle_documents, [:vehicle_id])
    create index(:vehicle_documents, [:vehicle_id, :type])

    create index(:payment_transactions, [:driver_id])
  end
end
