defmodule FraytElixir.Repo.Migrations.AddAddressToDeliveryBatch do
  use Ecto.Migration

  def change do
    alter table(:delivery_batches) do
      add :address_id, references(:addresses, type: :binary_id, on_delete: :nothing)
    end
  end
end
