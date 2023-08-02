defmodule FraytElixir.Repo.Migrations.CreateApiAccounts do
  use Ecto.Migration

  def change do
    create table(:api_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, :string
      add :secret, :string
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:api_accounts, [:shipper_id])
  end
end
