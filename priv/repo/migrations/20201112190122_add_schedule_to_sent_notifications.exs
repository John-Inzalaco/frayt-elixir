defmodule FraytElixir.Repo.Migrations.AddScheduleToSentNotifications do
  use Ecto.Migration

  def change do
    alter table(:sent_notifications) do
      add :schedule_id, references(:schedules, type: :binary_id, on_delete: :nothing)
    end
  end
end
