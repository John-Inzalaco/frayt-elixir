defmodule FraytElixir.Repo.Migrations.CreateDriverMetrics do
  use Ecto.Migration

  def change do
    create table(:driver_metrics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :rating, :float
      add :rated_matches, :integer
      add :completed_matches, :integer
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:driver_metrics, [:driver_id])
  end
end
