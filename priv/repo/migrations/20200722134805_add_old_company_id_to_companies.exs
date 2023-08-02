defmodule FraytElixir.Repo.Migrations.AddOldCompanyIdToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :old_company_id, :text
    end
  end
end
