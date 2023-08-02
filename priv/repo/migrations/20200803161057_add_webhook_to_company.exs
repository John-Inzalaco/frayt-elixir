defmodule FraytElixir.Repo.Migrations.AddWebhookToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :webhook_url, :string
      add :webhook_token, :string
    end
  end
end
