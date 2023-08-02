defmodule FraytElixir.Repo.Migrations.AddIdentifierToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :identifier, :string
    end
  end
end
