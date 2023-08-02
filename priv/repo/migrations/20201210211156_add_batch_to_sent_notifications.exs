defmodule FraytElixir.Repo.Migrations.AddBatchToSentNotifications do
  use Ecto.Migration

  def change do
    alter table(:sent_notifications) do
      add :delivery_batch_id, references(:delivery_batches, type: :binary_id, on_delete: :nothing)
    end
  end
end
