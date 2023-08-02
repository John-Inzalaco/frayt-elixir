defmodule FraytElixir.Repo.Migrations.AddCalculateTollsToMarket do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :calculate_tolls, :boolean
    end
  end
end
