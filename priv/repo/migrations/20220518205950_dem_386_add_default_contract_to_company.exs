defmodule FraytElixir.Repo.Migrations.DEM386AddDefaultContractToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      remove :default_contract, :string
      add :default_contract_id, references(:contracts, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:companies, [:default_contract_id])
  end
end
