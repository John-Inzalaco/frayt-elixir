defmodule FraytElixir.Repo.Migrations.AddAdminNotesToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :admin_notes, :string
    end
  end
end
