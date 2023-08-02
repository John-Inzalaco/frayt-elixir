defmodule FraytElixir.Repo.Migrations.AddDeliveryBatchIdToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :delivery_batch_id, references(:delivery_batches, type: :binary_id, on_delete: :nothing)
    end
  end
end
