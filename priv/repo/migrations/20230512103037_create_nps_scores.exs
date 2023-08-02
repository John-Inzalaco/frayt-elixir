defmodule FraytElixir.Repo.Migrations.CreateNpsScores do
  use Ecto.Migration

  def change do
    create table(:nps_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :user_type, :string
      add :score, :integer
      add :feedback, :string

      timestamps()
    end
  end
end
