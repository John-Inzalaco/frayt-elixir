defmodule FraytElixir.Repo.Migrations.AddLoadUnloadToDrivers do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :can_load, :boolean
    end
  end
end
