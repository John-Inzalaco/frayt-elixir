defmodule FraytElixir.Repo.Migrations.CreateDrivers do
  use Ecto.Migration

  def change do
    create table(:drivers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :first_name, :string
      add :last_name, :string
      add :phone_number, :string
      add :license_number, :string
      add :license_state, :string
      add :ssn, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :address_id, references(:addresses, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:drivers, [:user_id])
    create index(:drivers, [:address_id])
  end
end
