defmodule FraytElixir.Repo.Migrations.AddScheduleToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :schedule_id, references(:schedules, type: :binary_id, on_delete: :nothing)
    end
  end
end
