defmodule FraytElixir.Repo.Migrations.DEM498AddPartitionsForSentNotifications do
  use Ecto.Migration

  def change do
    drop index(:sent_notifications, [:driver_id])
    drop index(:sent_notifications, [:match_id])
    drop index(:sent_notifications, [:shipper_id])
    drop index(:sent_notifications, [:notification_batch_id])

    rename table(:sent_notifications), to: table(:sent_notifications_archive)

    create table(:sent_notifications,
             primary_key: false,
             options: "PARTITION BY RANGE (inserted_at)"
           ) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :old_id, :bigint
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :delete_all)
      add :match_id, references(:matches, type: :binary_id, on_delete: :delete_all)
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :delete_all)
      add :schedule_id, references(:schedules, type: :binary_id, on_delete: :delete_all)

      add :delivery_batch_id,
          references(:delivery_batches, type: :binary_id, on_delete: :delete_all)

      add :notification_batch_id,
          references(:notification_batches, type: :binary_id, on_delete: :delete_all)

      add :admin_user_id, references(:admin_users, type: :binary_id, on_delete: :nilify_all)

      add :phone_number, :string
      add :device_id, :string
      add :notification_type, :string
      add :external_id, :string

      add :inserted_at, :naive_datetime, null: false, primary_key: true
      add :updated_at, :naive_datetime, null: false
    end

    create index(:sent_notifications, [:driver_id])
    create index(:sent_notifications, [:match_id])
    create index(:sent_notifications, [:shipper_id])
    create index(:sent_notifications, [:schedule_id])
    create index(:sent_notifications, [:delivery_batch_id])
    create index(:sent_notifications, [:notification_batch_id])
    create index(:sent_notifications, [:admin_user_id])
  end
end
