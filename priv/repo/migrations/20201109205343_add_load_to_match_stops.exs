defmodule FraytElixir.Repo.Migrations.AddLoadToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :total_volume, :integer
    end
  end
end
