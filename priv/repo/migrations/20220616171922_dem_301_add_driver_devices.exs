defmodule FraytElixir.Repo.Migrations.DEM301AddDriverDevices do
  use Ecto.Migration

  def change do
    create table(:driver_devices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_uuid, :string
      add :device_model, :string
      add :player_id, :string
      add :os, :string
      add :os_version, :string
      add :is_tablet, :boolean
      add :is_location_enabled, :boolean
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:driver_devices, [:driver_id])

    alter table(:drivers) do
      add :default_device_id,
          references(:driver_devices, type: :binary_id, on_delete: :delete_all)
    end

    create index(:drivers, [:default_device_id])

    execute &migrate_one_signal_id_to_devices/0, &migrate_devices_to_one_signal_id/0

    alter table(:drivers) do
      remove :one_signal_id, :string
    end
  end

  defp migrate_one_signal_id_to_devices do
    repo().query!("""
    WITH driver_to_modify AS (
      SELECT id as driver_id,
             one_signal_id as player_id
        FROM drivers
    )
    INSERT INTO driver_devices (id, player_id, driver_id, inserted_at, updated_at)
    (
      SELECT gen_random_uuid() as id,
             driver.player_id,
             driver.driver_id,
             NOW() as inserted_at,
             NOW() as updated_at
        FROM driver_to_modify as driver
    )
    """)

    flush()

    repo().query!("""
      UPDATE drivers d
         SET default_device_id = dd.id
        FROM driver_devices AS dd
       WHERE dd.driver_id = d.id
    """)
  end

  defp migrate_devices_to_one_signal_id do
    repo().query!("""
      UPDATE drivers d
         SET one_signal_id = dd.player_id
        FROM driver_devices AS dd
       WHERE dd.driver_id = d.id
    """)
  end
end
