defmodule FraytElixir.Repo.Migrations.AddDriverLocationIndexes do
  use Ecto.Migration

  def change do
    create index(:drivers, [:current_location_id, :current_location_inserted_at])

    create index(:driver_locations, ["(geo_location::geography)"],
             name: :driver_location_geo_location_gist_index,
             using: "gist"
           )
  end
end
