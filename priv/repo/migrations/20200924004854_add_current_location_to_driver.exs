defmodule FraytElixir.Repo.Migrations.AddCurrentLocationToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :current_location_id,
          references(:driver_locations, on_delete: :nothing)
    end

    create index(:drivers, [:current_location_id])
  end
end
