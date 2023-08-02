defmodule FraytElixir.Repo.Migrations.MoveApiAccountsFromShippersToCompanies do
  use Ecto.Migration

  def change do
    alter table(:api_accounts) do
      remove :shipper_id
      add :company_id, references(:companies, type: :binary_id)
    end
  end
end
