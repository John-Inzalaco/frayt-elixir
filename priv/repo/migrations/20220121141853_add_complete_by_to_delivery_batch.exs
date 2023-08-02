defmodule FraytElixir.Repo.Migrations.AddCompleteByToDeliveryBatch do
  use Ecto.Migration

  def change do
    alter table(:delivery_batches) do
      add :complete_by, :utc_datetime
    end
  end
end
