defmodule FraytElixir.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :location, :string
      add :store_number, :string
      add :email, :string
      add :company_id, references(:companies, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:locations, [:company_id])
  end
end
