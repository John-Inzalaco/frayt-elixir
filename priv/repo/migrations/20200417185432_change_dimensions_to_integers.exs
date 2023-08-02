defmodule FraytElixir.Repo.Migrations.ChangeDimensionsToIntegers do
  use Ecto.Migration

  def change do
    alter table("matches") do
      modify :width, :integer
      modify :height, :integer
      modify :length, :integer
    end
  end
end
