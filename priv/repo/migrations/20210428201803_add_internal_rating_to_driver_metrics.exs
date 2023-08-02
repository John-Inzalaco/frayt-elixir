defmodule FraytElixir.Repo.Migrations.AddInternalRatingToDriverMetrics do
  use Ecto.Migration

  def change do
    alter table(:driver_metrics) do
      add :internal_rating, :float
    end
  end
end
