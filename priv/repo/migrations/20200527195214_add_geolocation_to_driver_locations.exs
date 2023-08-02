defmodule FraytElixir.Repo.Migrations.AddGeolocationToDriverLocations do
  use Ecto.Migration

  def change do
    alter table(:driver_locations) do
      remove :lat
      remove :lng
      add :geo_location, :geometry
    end
  end
end
