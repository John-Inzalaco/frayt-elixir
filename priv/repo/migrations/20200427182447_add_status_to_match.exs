defmodule FraytElixir.Repo.Migrations.AddStatusToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :state, :string
    end
  end
end
