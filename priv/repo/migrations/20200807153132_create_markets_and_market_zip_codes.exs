defmodule FraytElixir.Repo.Migrations.CreateMarketsAndMarketZipCodes do
  use Ecto.Migration

  def change do
    create table(:markets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :markup, :float

      timestamps()
    end

    create table(:market_zip_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :zip, :string
      add :market_id, references(:markets, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:market_zip_codes, [:zip])
  end
end
