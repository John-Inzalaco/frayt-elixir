defmodule FraytElixir.Repo.Migrations.AddLockVersionToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :lock_version, :integer, default: 1
    end
  end
end
