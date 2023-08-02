defmodule FraytElixir.Repo.Migrations.AddFieldsToDeliveryBatch do
  use Ecto.Migration

  def change do
    alter table(:delivery_batches) do
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :nothing)
      add :po, :string
      add :vehicle_class, :integer
      add :service_level, :integer
    end
  end
end
