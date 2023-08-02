defmodule FraytElixir.Repo.Migrations.AddSmartVehicleSelectionToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :autoselect_vehicle_class, :boolean
    end
  end
end
