defmodule FraytElixir.Repo.Migrations.AddMetaFieldToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :meta, :map, default: %{}
    end
  end
end
