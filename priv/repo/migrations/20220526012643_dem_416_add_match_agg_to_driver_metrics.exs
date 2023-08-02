defmodule FraytElixir.Repo.Migrations.DEM416AddMatchAggToDriverMetrics do
  use Ecto.Migration

  def change do
    alter table(:driver_metrics) do
      add :canceled_matches, :integer
      add :total_earned, :integer
    end
  end
end
