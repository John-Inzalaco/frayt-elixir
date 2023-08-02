defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM-117-case-insensitve-login-comparison" do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION citext"

    alter table(:users) do
      modify(:email, :citext, null: false)
    end

    drop index(:users, [:email])

    create index(:users, [:email], unique: true)
  end

  def down do
    execute "DROP EXTENSION citext"

    alter table(:users) do
      modify(:email, :string, null: false)
    end
  end
end
