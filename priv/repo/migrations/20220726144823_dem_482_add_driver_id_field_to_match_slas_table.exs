defmodule FraytElixir.Repo.Migrations.DEM482AddDriverIdFieldToMatchSlasTable do
  use Ecto.Migration

  def change do
    alter table(:match_slas) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :completed_at, :utc_datetime
    end

    drop unique_index(:match_slas, [:match_id, :type])

    create unique_index(:match_slas, [:match_id, :type, :driver_id])
  end
end
