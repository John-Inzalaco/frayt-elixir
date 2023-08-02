defmodule FraytElixir.Repo.Migrations.DEM435AddUniqueIndexToDrivers do
  use Ecto.Migration

  def change do
    # Ensure there are no duplicate metrics entries for drivers.
    execute """
      DELETE FROM driver_metrics as dm WHERE dm.id IN (
        SELECT
        id from (
          select
            id,
            ROW_NUMBER() OVER (
              PARTITION BY driver_id ORDER BY updated_at DESC
            ) as row_num
            from driver_metrics
        ) as dms
        WHERE dms.row_num > 1
      )
    """

    drop index(:driver_metrics, [:driver_id])
    create unique_index(:driver_metrics, [:driver_id])
  end
end
