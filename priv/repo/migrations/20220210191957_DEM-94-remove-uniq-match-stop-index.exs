defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM94RemoveUniqueMatchStopIndex" do
  use Ecto.Migration

  def change do
    drop unique_index(:match_stops, [:match_id, :index])
  end
end
