defmodule FraytElixir.Repo.Migrations.AddWebhookConfigToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :webhook_config, :map
    end
  end
end
