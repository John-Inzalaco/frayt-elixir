defmodule FraytElixir.Repo.Migrations.DEM498AddPartitionsForDriverLocations do
  use Ecto.Migration

  def change do
    drop index(:driver_locations, [:driver_id])

    rename table(:driver_locations), to: table(:driver_locations_archive)

    create table(:driver_locations,
             primary_key: false,
             options: "PARTITION BY RANGE (inserted_at)"
           ) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :old_id, :bigint
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :geo_location, :geometry
      add :formatted_address, :string

      add :inserted_at, :utc_datetime_usec, null: false, primary_key: true
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:driver_locations, [:driver_id])

    rename table(:match_state_transitions), :driver_location_id, to: :old_driver_location_id
    rename table(:match_stop_state_transitions), :driver_location_id, to: :old_driver_location_id
    rename table(:drivers), :current_location_id, to: :old_current_location_id

    rename_constraint(:match_state_transitions, :match_state_transitions_driver_location_id_fkey,
      to: :match_state_transitions_old_driver_location_id_fkey
    )

    rename_constraint(
      :match_stop_state_transitions,
      :match_stop_state_transitions_driver_location_id_fkey,
      to: :match_stop_state_transitions_old_driver_location_id_fkey
    )

    rename_constraint(:drivers, :drivers_current_location_id_fkey,
      to: :drivers_old_current_location_id_fkey
    )
  end

  defp rename_constraint(table, current_name, to: updated_name) do
    execute(
      fn -> rename_constraint(table, current_name, updated_name) end,
      fn -> rename_constraint(table, updated_name, current_name) end
    )
  end

  defp rename_constraint(table, current_name, updated_name) do
    repo().query!("ALTER TABLE #{table} RENAME CONSTRAINT #{current_name} TO #{updated_name}")
  end
end
