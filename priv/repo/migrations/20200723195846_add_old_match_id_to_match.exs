defmodule FraytElixir.Repo.Migrations.AddOldMatchIdToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :old_match_id, :text
    end
  end
end
