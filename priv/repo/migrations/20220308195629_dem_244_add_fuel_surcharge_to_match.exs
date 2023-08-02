defmodule FraytElixir.Repo.Migrations.DEM244_AddFuelSurchargeToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :fuel_surcharge, :float
    end
  end
end
