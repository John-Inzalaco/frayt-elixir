defmodule FraytElixir.Repo.Migrations.CreateMetricSettings do
  use Ecto.Migration

  def change do
    create table(:metric_settings) do
      add :fulfillment_goal, :integer

      timestamps()
    end
  end
end
