defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-94-OptimizeMatchStopsWithTomTom" do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :optimized_stops, :boolean, default: false
    end
  end
end
