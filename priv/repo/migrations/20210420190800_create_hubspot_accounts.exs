defmodule FraytElixir.Repo.Migrations.CreateHubspotAccounts do
  use Ecto.Migration

  def change do
    create table(:hubspot_accounts) do
      add :refresh_token, :text
      add :access_token, :text
      add :expires_at, :utc_datetime

      timestamps()
    end
  end
end
