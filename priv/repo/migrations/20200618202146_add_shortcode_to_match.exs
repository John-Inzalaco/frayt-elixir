defmodule FraytElixir.Repo.Migrations.AddShortcodeToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :shortcode, :string
    end
  end
end
