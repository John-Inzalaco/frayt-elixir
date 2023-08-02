defmodule FraytElixir.Repo.Migrations.AddEnterpriseToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :is_enterprise, :boolean
    end
  end
end
