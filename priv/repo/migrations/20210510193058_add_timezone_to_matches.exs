defmodule FraytElixir.Repo.Migrations.AddTimezoneToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :timezone, :string
    end
  end
end
