defmodule FraytElixir.Repo.Migrations.AddStopIndexes do
  use Ecto.Migration

  def change do
    create index(:match_stops, [:match_id, :index], unique: true)
  end
end
