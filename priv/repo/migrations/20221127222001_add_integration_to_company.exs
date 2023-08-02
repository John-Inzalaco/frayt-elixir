defmodule FraytElixir.Repo.Migrations.AddIntegrationToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :integration, :string
      add :integration_id, :string
      add :api_key, :string
    end
  end
end
