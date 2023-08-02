defmodule FraytElixir.Repo.Migrations.DEM506AddNameToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :name, :string
    end
  end
end
