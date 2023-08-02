defmodule FraytElixir.Repo.Migrations.Dem448CreateContractSlasTable do
  use Ecto.Migration

  def change do
    create table(:contract_slas, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :contract_id,
          references(:contracts, type: :binary_id, on_delete: :nothing),
          null: false

      add :type, :string, null: false
      add :duration, :string, null: false

      timestamps()
    end

    create unique_index(:contract_slas, [:contract_id, :type])
  end
end
