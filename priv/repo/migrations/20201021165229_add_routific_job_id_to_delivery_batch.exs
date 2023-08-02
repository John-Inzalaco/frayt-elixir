defmodule FraytElixir.Repo.Migrations.AddRoutificJobIdToDeliveryBatch do
  use Ecto.Migration

  def change do
    alter table(:delivery_batches) do
      add :routific_job_id, :string
    end
  end
end
