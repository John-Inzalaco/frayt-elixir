defmodule FraytElixir.Repo.Migrations.AddSalesGoalToAdminUser do
  use Ecto.Migration

  def change do
    alter table(:admin_users) do
      add :sales_goal, :integer
    end
  end
end
