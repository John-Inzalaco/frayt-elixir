defmodule FraytElixir.Repo.Migrations.AddIdentifierToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :identifier, :string
    end
  end
end
