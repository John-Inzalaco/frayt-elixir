defmodule FraytElixir.Repo.Migrations.AddPickupNotesToDeliveryBatch do
  use Ecto.Migration

  def change do
    alter table(:delivery_batches) do
      add :pickup_notes, :text
    end
  end
end
