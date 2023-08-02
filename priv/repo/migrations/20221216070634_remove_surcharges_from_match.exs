defmodule FraytElixir.Repo.Migrations.RemoveSurchargesFromMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :time_surcharge, :float
      remove :fuel_surcharge, :float
    end
  end
end
