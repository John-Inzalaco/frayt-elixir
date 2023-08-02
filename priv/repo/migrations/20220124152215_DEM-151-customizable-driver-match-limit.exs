defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-151-CustomizableDriverMatchLimit" do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :active_match_limit, :integer, default: nil
    end
  end
end
