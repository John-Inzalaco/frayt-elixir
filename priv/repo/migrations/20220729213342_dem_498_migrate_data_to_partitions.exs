defmodule FraytElixir.Repo.Migrations.DEM498MigrateDataToPartitions do
  use Ecto.Migration
  import FraytElixir.Helpers.TablePartitioning

  @sent_notification_columns [
    :driver_id,
    :match_id,
    :shipper_id,
    :schedule_id,
    :delivery_batch_id,
    :notification_batch_id,
    :admin_user_id,
    :phone_number,
    :device_id,
    :notification_type,
    :external_id,
    :inserted_at,
    :updated_at,
    id: :old_id
  ]

  @driver_location_columns [
    :driver_id,
    :geo_location,
    :formatted_address,
    :inserted_at,
    :updated_at,
    id: :old_id
  ]

  def up do
    alter table(:match_state_transitions) do
      add :driver_location_inserted_at, :utc_datetime_usec

      add :driver_location_id,
          references(:driver_locations,
            type: :binary_id,
            on_delete: :nilify_all,
            with: [driver_location_inserted_at: :inserted_at]
          )
    end

    alter table(:match_stop_state_transitions) do
      add :driver_location_inserted_at, :utc_datetime_usec

      add :driver_location_id,
          references(:driver_locations,
            type: :binary_id,
            on_delete: :nilify_all,
            with: [driver_location_inserted_at: :inserted_at]
          )
    end

    alter table(:drivers) do
      add :current_location_inserted_at, :utc_datetime_usec

      add :current_location_id,
          references(:driver_locations,
            type: :binary_id,
            on_delete: :nilify_all,
            with: [current_location_inserted_at: :inserted_at]
          )
    end

    migrate_to_partition(:sent_notifications,
      from: :sent_notifications_archive,
      columns: @sent_notification_columns
    )

    migrate_to_partition(:driver_locations,
      from: :driver_locations_archive,
      columns: @driver_location_columns
    )

    migrate_to_partition_refs()

    alter table(:match_state_transitions) do
      remove :old_driver_location_id
    end

    alter table(:match_stop_state_transitions) do
      remove :old_driver_location_id
    end

    alter table(:drivers) do
      remove :old_current_location_id
    end

    alter table(:sent_notifications) do
      remove :old_id
    end

    alter table(:driver_locations) do
      remove :old_id
    end

    drop table(:sent_notifications_archive)

    drop table(:driver_locations_archive)
  end

  def down do
    create table(:sent_notifications_archive) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :nothing)
      add :schedule_id, references(:schedules, type: :binary_id, on_delete: :nothing)
      add :delivery_batch_id, references(:delivery_batches, type: :binary_id, on_delete: :nothing)
      add :notification_batch_id, references(:notification_batches, type: :binary_id)
      add :admin_user_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
      add :phone_number, :string
      add :device_id, :string
      add :notification_type, :string
      add :external_id, :string

      timestamps()
    end

    create table(:driver_locations_archive) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :geo_location, :geometry
      add :formatted_address, :string

      timestamps()
    end

    alter table(:match_state_transitions) do
      add :old_driver_location_id, references(:driver_locations_archive)
    end

    alter table(:match_stop_state_transitions) do
      add :old_driver_location_id, references(:driver_locations_archive)
    end

    alter table(:drivers) do
      add :old_current_location_id, references(:driver_locations_archive)
    end

    alter table(:sent_notifications) do
      add :old_id, :bigserial
    end

    alter table(:driver_locations) do
      add :old_id, :bigserial
    end

    flush()

    migrate_from_partition(:sent_notifications,
      to: :sent_notifications_archive,
      columns: @sent_notification_columns
    )

    migrate_from_partition(:driver_locations,
      to: :driver_locations_archive,
      columns: @driver_location_columns
    )

    migrate_from_partition_refs()

    alter table(:match_state_transitions) do
      remove :driver_location_inserted_at
      remove :driver_location_id
    end

    alter table(:match_stop_state_transitions) do
      remove :driver_location_inserted_at
      remove :driver_location_id
    end

    alter table(:drivers) do
      remove :current_location_inserted_at
      remove :current_location_id
    end

    flush()

    drop_all_partitions(:sent_notifications)
    drop_all_partitions(:driver_locations)
  end

  defp migrate_to_partition_refs, do: migrate_ids(:to)
  defp migrate_from_partition_refs, do: migrate_ids(:from)

  defp migrate_ids(direction) do
    migrate_ids(
      :drivers,
      :driver_locations,
      [:current_location_id, :current_location_inserted_at],
      direction
    )

    migrate_ids(
      :match_state_transitions,
      :driver_locations,
      [:driver_location_id, :driver_location_inserted_at],
      direction
    )

    migrate_ids(
      :match_stop_state_transitions,
      :driver_locations,
      [:driver_location_id, :driver_location_inserted_at],
      direction
    )
  end

  defp migrate_ids(table, foreign_table, [id_key, inserted_at_key], direction) do
    old_id_key = String.to_atom("old_#{id_key}")

    flush()

    case direction do
      :to ->
        repo().query!("""
        UPDATE #{table} SET #{id_key} = f.id, #{inserted_at_key} = f.inserted_at
        FROM #{foreign_table} AS f
        WHERE f.old_id = #{old_id_key}
        """)

      :from ->
        repo().query!("""
        UPDATE #{table} SET #{old_id_key} = f.old_id
        FROM #{foreign_table} AS f
        WHERE f.id = #{id_key}
        """)
    end
  end
end
