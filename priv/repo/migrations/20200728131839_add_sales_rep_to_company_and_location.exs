defmodule FraytElixir.Repo.Migrations.AddSalesRepToCompanyAndLocation do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add :sales_rep_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end

    alter table(:locations) do
      add :sales_rep_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end
  end
end
