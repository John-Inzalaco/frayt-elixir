defmodule FraytElixir.Repo.Migrations.CreateMatchTags do
  use Ecto.Migration

  def change do
    create table(:match_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :match_id, references(:matches, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:match_tags, [:match_id])
  end
end
