defmodule FraytElixir.Repo.Migrations.CreateVehicles do
  use Ecto.Migration

  def change do
    create table(:vehicles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :make, :string
      add :model, :string
      add :year, :integer
      add :vin, :string
      add :vehicle_class, :integer
      add :license_plate, :string
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:vehicles, [:driver_id])
  end
end
