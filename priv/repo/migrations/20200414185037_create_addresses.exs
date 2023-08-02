defmodule FraytElixir.Repo.Migrations.CreateAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses) do
      add :address, :string
      add :lat, :float
      add :lng, :float

      timestamps()
    end
  end
end
