defmodule FraytElixir.Repo.Migrations.CreateReplacedDriverImages do
  use Ecto.Migration

  def change do
    create table(:replaced_driver_images, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :descriptor, :string
      add :image, :string
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end
  end
end
