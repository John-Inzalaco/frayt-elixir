defmodule FraytElixir.Repo.Migrations.CreateMatchStateTransitions do
  use Ecto.Migration

  def change do
    create table(:match_state_transitions) do
      add :from, :string
      add :to, :string
      add :transitioned_at, :utc_datetime
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:match_state_transitions, [:match_id])
  end
end
