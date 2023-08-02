defmodule FraytElixir.Repo.Migrations.CreateRejectedMatchesTable do
  use Ecto.Migration

  def change do
    create table(:rejected_matches) do
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:rejected_matches, [:driver_id])
  end
end
