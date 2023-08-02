defmodule FraytElixir.Repo.Migrations.AddNotesToMatchStateTransitions do
  use Ecto.Migration

  def change do
    alter table(:match_state_transitions) do
      add :notes, :string
    end
  end
end
