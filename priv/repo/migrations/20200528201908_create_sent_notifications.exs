defmodule FraytElixir.Repo.Migrations.CreateSentNotifications do
  use Ecto.Migration

  def change do
    create table(:sent_notifications) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)
      add :external_id, :string

      timestamps()
    end

    create index(:sent_notifications, [:driver_id])
    create index(:sent_notifications, [:match_id])
  end
end
