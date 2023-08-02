defmodule FraytElixir.Repo.Migrations.AddRegionToMarkets do
  use Ecto.Migration

  def change do
    alter table(:markets) do
      add :region, :string
      add :currently_hiring, :boolean, default: false
    end
  end
end
