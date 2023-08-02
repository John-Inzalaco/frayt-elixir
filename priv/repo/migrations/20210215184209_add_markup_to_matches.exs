defmodule FraytElixir.Repo.Migrations.AddMarkupToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :markup, :boolean

      add :markup, :float
    end
  end
end
