defmodule FraytElixir.Repo.Migrations.AddDimensionsToMatch do
  use Ecto.Migration

  def change do
    alter table("matches") do
      add :width, :float
      add :height, :float
      add :length, :float
      add :pieces, :integer
    end
  end
end
