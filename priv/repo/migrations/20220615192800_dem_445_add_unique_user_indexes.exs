defmodule FraytElixir.Repo.Migrations.DEM445AddUniqueUserIndexes do
  use Ecto.Migration

  def change do
    drop index(:shippers, [:user_id])
    create unique_index(:shippers, [:user_id])
    drop index(:drivers, [:user_id])
    create unique_index(:drivers, [:user_id])
    drop index(:admin_users, [:user_id])
    create unique_index(:admin_users, [:user_id])
  end
end
