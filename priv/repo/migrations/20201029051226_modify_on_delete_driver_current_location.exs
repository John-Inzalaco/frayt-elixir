defmodule FraytElixir.Repo.Migrations.ModifyOnDeleteDriverCurrentLocation do
  use Ecto.Migration

  def up do
    drop constraint(:drivers, "drivers_current_location_id_fkey")

    alter table(:drivers) do
      modify(:current_location_id, references(:driver_locations, on_delete: :nilify_all))
    end
  end

  def down do
    drop constraint(:drivers, "drivers_current_location_id_fkey")

    alter table(:drivers) do
      modify(:current_location_id, references(:driver_locations, on_delete: :nothing))
    end
  end
end
