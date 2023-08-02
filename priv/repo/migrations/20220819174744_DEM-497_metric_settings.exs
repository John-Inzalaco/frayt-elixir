defmodule FraytElixir.Repo.Migrations.DEM497MetricSettings do
  use Ecto.Migration

  def change do
    alter table(:metric_settings) do
      add :sla_goal, :integer
    end
  end
end
