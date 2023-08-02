defmodule FraytElixir.Repo.Migrations.CreateVehicleImages do
  use Ecto.Migration

  def change do
    create table(:vehicle_images, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :descriptor, :string
      add :image, :string
      add :vehicle_id, references(:vehicles, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end
  end
end
