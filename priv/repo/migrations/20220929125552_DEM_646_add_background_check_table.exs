defmodule FraytElixir.Repo.Migrations.DEM646AddBackgroundCheckTable do
  use Ecto.Migration

  def change do
    create table(:background_checks, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :customer_id, :string
      add :transaction_id, :string
      add :amount_charged, :integer
      add :state, :string, default: "pending"

      timestamps()
    end
  end
end
