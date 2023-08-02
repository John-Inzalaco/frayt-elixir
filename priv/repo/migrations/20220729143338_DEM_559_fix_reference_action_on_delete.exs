defmodule FraytElixir.Repo.Migrations.DEM559FixReferenceActionOnDelete do
  use Ecto.Migration

  def up do
    drop(constraint(:drivers, "drivers_default_device_id_fkey"))
    drop(constraint(:driver_devices, "driver_devices_driver_id_fkey"))

    alter table(:drivers) do
      modify :default_device_id,
             references(:driver_devices, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:driver_devices) do
      modify :driver_id, references(:drivers, type: :binary_id, on_delete: :delete_all)
    end
  end

  def down do
    drop(constraint(:drivers, "drivers_default_device_id_fkey"))
    drop(constraint(:driver_devices, "driver_devices_driver_id_fkey"))

    alter table(:drivers) do
      modify :default_device_id,
             references(:driver_devices, type: :binary_id, on_delete: :delete_all)
    end

    alter table(:driver_devices) do
      modify :driver_id, references(:drivers, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
