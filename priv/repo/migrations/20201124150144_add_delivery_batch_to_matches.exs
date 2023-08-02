defmodule FraytElixir.Repo.Migrations.AddDeliveryBatchToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :delivery_batch_id, references(:delivery_batches, type: :binary_id, on_delete: :nothing)
    end
  end
end
