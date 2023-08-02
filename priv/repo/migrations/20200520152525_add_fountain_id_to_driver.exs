defmodule FraytElixir.Repo.Migrations.AddFountainIdToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :fountain_id, :string
    end

    create unique_index(:drivers, [:fountain_id])
  end
end
