defmodule FraytElixir.Repo.Migrations.CreateNotificationBatches do
  use Ecto.Migration

  def change do
    create table(:notification_batches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :network_operator_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    alter table(:sent_notifications) do
      add :notification_batch_id, references(:notification_batches, type: :binary_id)
    end

    create index(:sent_notifications, [:notification_batch_id])
    create index(:notification_batches, [:network_operator_id])
    create index(:notification_batches, [:match_id])
  end
end
