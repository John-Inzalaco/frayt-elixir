defmodule FraytElixir.Repo.Migrations.DEM808ChangeMatchStopItemWeightToFloat do
  use Ecto.Migration

  def change do
    alter table(:match_stop_items) do
      modify :weight, :float, from: :int
    end
  end
end
