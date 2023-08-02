defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-281-AddingPoToMatchStops" do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :po, :string
    end
  end
end
