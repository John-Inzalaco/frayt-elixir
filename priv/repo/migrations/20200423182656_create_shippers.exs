defmodule FraytElixir.Repo.Migrations.CreateShippers do
  use Ecto.Migration

  def change do
    create table(:shippers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :city, :string
      add :state, :string
      add :zip, :string
      add :address, :string
      add :company, :string
      add :agreement, :boolean, default: false, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:shippers, [:user_id])
  end
end
