defmodule FraytElixir.Repo.Migrations.AddDriverCutToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :driver_cut, :float
    end
  end
end
