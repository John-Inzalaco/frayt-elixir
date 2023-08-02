defmodule FraytElixir.Repo.Migrations.AddDisabledToAdminUser do
  use Ecto.Migration

  def change do
    alter table(:admin_users) do
      add :disabled, :boolean
    end
  end
end
