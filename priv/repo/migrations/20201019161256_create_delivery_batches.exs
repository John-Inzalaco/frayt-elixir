defmodule FraytElixir.Repo.Migrations.CreateDeliveryBatches do
  use Ecto.Migration

  def change do
    create table(:delivery_batches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pickup_at, :utc_datetime
      add :location_id, references(:locations, on_delete: :nothing, type: :binary_id)
      add :state, :string

      timestamps()
    end

    create index(:delivery_batches, [:location_id])
  end
end
