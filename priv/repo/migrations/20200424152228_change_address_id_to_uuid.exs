defmodule FraytElixir.Repo.Migrations.ChangeAddressIdToUuid do
  use Ecto.Migration

  def change do
    drop_if_exists table(:matches)
    drop_if_exists table(:addresses)

    create table(:addresses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :address, :string
      add :lat, :float
      add :lng, :float

      timestamps()
    end
  end
end
