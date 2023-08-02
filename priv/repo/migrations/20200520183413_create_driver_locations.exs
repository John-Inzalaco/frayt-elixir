defmodule FraytElixir.Repo.Migrations.CreateDriverLocations do
  use Ecto.Migration

  def change do
    create table(:driver_locations) do
      add :lat, :float
      add :lng, :float
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:driver_locations, [:driver_id])
  end
end
