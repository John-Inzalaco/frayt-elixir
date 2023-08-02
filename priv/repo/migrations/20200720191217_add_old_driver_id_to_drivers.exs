defmodule FraytElixir.Repo.Migrations.AddOldDriverIdToDrivers do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :old_driver_id, :text
    end
  end
end
