defmodule FraytElixir.Repo.Migrations.AddInvoicePeriodToLocation do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      add :invoice_period, :integer
    end
  end
end
