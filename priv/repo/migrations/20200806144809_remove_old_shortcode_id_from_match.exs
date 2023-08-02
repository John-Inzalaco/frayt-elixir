defmodule FraytElixir.Repo.Migrations.RemoveOldShortcodeIDFromMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :old_shortcode_id
    end
  end
end
