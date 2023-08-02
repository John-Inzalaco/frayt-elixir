defmodule FraytElixir.Repo.Migrations.CreateDriversSchedules do
  use Ecto.Migration

  def change do
    create table(:drivers_schedules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :schedule_id, references(:schedules, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:drivers_schedules, [:driver_id])
    create index(:drivers_schedules, [:schedule_id])
    create unique_index(:drivers_schedules, [:driver_id, :schedule_id])
  end
end
