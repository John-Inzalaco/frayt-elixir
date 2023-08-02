defmodule FraytElixir.Repo.Migrations.AddDistanceToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :distance, :float
    end

    rename table(:matches), :distance, to: :total_distance
  end
end
