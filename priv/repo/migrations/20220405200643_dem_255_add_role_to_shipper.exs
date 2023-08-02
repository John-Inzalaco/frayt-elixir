defmodule FraytElixir.Repo.Migrations.DEM255AddRoleToShipper do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :role, :string
    end

    execute "update shippers set role = 'member' where role is null"
  end
end
