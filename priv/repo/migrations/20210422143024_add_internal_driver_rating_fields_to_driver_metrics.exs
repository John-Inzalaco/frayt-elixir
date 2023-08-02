defmodule FraytElixir.Repo.Migrations.AddInternalDriverRatingFieldsToDriverMetrics do
  use Ecto.Migration

  def change do
    alter table(:driver_metrics) do
      add :activity_rating, :float
      add :fulfillment_rating, :float
      add :sla_rating, :float
    end
  end
end
