defmodule FraytElixir.Repo.Migrations.AddGeolocationToAddresses do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      remove :lat
      remove :lng
      add :geo_location, :geometry
    end
  end
end
