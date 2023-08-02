defmodule FraytElixir.Repo.Migrations.CreateSchedules do
  use Ecto.Migration

  def change do
    create table(:schedules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :monday, :time
      add :tuesday, :time
      add :wednesday, :time
      add :thursday, :time
      add :friday, :time
      add :saturday, :time
      add :sunday, :time
      add :min_drivers, :integer
      add :max_drivers, :integer
      add :sla, :integer
      add :location_id, references(:locations, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:schedules, [:location_id])
  end
end
