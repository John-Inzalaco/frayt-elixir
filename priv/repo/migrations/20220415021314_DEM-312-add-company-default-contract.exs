defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-312" do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :default_contract, :string
    end
  end
end
