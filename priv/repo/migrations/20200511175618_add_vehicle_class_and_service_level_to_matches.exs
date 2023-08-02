defmodule FraytElixir.Repo.Migrations.AddVehicleClassAndServiceLevelToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :vehicle_class, :integer
      add :service_level, :integer
    end
  end
end
