defmodule FraytElixir.Repo.Migrations.AddTurnStateToBackgroundCheck do
  use Ecto.Migration

  def change do
    alter table(:background_checks) do
      add :turn_state, :string
    end
  end
end
