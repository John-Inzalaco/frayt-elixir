defmodule FraytElixir.Repo.Migrations.AddThemeToAdminUser do
  use Ecto.Migration

  def change do
    alter table(:admin_users) do
      add :site_theme, :string
    end
  end
end
