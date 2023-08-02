defmodule FraytElixir.Repo.Migrations.AddMarketIdToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :market_id, references(:markets, type: :binary_id, on_delete: :nothing)
    end

    create index(:matches, [:market_id])
  end
end
