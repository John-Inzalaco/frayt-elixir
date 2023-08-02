defmodule FraytElixir.Repo.Migrations.DropPlayerIdUniqueIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:driver_devices, [:player_id])
    create unique_index(:driver_devices, [:driver_id, :device_uuid])
  end
end
