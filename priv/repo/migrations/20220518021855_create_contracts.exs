defmodule FraytElixir.Repo.Migrations.CreateContracts do
  use Ecto.Migration

  def change do
    create table(:contracts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :pricing_contract, :string
      add :contract_key, :string
      add :disabled, :boolean
      add :company_id, references(:companies, on_delete: :nilify_all, type: :binary_id)

      timestamps()
    end

    alter table(:matches) do
      add :contract_id, references(:contracts, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:matches, [:contract_id])
    create index(:contracts, [:company_id])
    create unique_index(:contracts, [:contract_key, :company_id])
  end
end
