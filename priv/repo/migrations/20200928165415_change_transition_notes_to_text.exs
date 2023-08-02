defmodule FraytElixir.Repo.Migrations.ChangeTransitionNotesToText do
  use Ecto.Migration

  def change do
    alter table(:match_state_transitions) do
      modify :notes, :text
    end
  end
end
