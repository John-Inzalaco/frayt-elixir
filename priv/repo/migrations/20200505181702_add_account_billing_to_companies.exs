defmodule FraytElixir.Repo.Migrations.AddAccountBillingToCompanies do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :account_billing_enabled, :boolean, default: false, null: false
      add :invoice_period, :integer
    end
  end
end
