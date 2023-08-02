defmodule FraytElixir.Repo.Migrations.AddOldLocationIdToLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      add :old_location_id, :text
    end
  end
end
