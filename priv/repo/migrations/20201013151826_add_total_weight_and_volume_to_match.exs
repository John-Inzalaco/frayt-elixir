defmodule FraytElixir.Repo.Migrations.AddTotalWeightAndVolumeToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :total_volume, :integer
      add :total_weight, :integer
    end
  end
end
