defmodule FraytElixir.Repo.Migrations.AddQuestionairesToDriver do
  use Ecto.Migration

  def change do
    alter table(:drivers) do
      add :english_proficiency, :string
      add :market_id, references(:markets, type: :binary_id)
    end

    create index(:drivers, [:market_id])
  end
end
