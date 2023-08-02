defmodule FraytElixir.Repo.Migrations.CreateMatchStopStateTransitions do
  use Ecto.Migration

  def change do
    create table(:match_stop_state_transitions) do
      add :from, :string
      add :to, :string
      add :transitioned_at, :utc_datetime
      add :match_stop_id, references(:match_stops, on_delete: :nothing, type: :binary_id)
      add :notes, :string

      timestamps()
    end

    create index(:match_stop_state_transitions, [:match_stop_id])
  end
end
