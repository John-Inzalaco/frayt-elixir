defmodule FraytElixir.Repo.Migrations.AddContractMarketMultipliers do
  use Ecto.Migration

  def change do
    create table(:contract_market_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :contract_id, references(:contracts, on_delete: :delete_all, type: :binary_id)

      add :market_id, references(:markets, on_delete: :delete_all, type: :binary_id)

      add :multiplier, :float, null: false
    end

    create unique_index(:contract_market_configs, [:contract_id, :market_id])
  end
end
