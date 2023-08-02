defmodule FraytElixir.Repo.Migrations.AddHasBoxTrucksToMarket do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :has_box_trucks, :boolean
    end
  end
end
