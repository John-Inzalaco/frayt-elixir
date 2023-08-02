defmodule FraytElixir.Repo.Migrations.AddCodeField do
  use Ecto.Migration

  def change do
    alter table(:match_state_transitions) do
      add :code, :string
    end
  end
end
