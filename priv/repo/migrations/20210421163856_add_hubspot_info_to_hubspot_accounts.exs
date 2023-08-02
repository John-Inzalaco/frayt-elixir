defmodule FraytElixir.Repo.Migrations.AddHubspotInfoToHubspotAccounts do
  use Ecto.Migration

  def change do
    alter table(:hubspot_accounts) do
      add :hubspot_id, :integer
      add :domain, :string
    end
  end
end
