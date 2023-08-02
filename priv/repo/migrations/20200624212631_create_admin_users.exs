defmodule FraytElixir.Repo.Migrations.CreateAdminUsers do
  use Ecto.Migration

  def change do
    create table(:admin_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :role, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:admin_users, [:user_id])
  end
end
