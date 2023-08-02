defmodule FraytElixir.Repo.Migrations.AddCapacityFieldsToVehicle do
  use Ecto.Migration

  def change do
    alter table(:vehicles) do
      add :cargo_area_width, :integer
      add :cargo_area_height, :integer
      add :cargo_area_length, :integer
      add :door_width, :integer
      add :door_height, :integer
      add :wheel_well_width, :integer
      add :max_cargo_weight, :integer
    end
  end
end
