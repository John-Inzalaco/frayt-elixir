defmodule FraytElixir.Repo.Migrations.AddLocationIdToShipper do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :location_id, references(:locations, type: :binary_id, on_delete: :nothing)
    end

    create index(:shippers, [:location_id])
  end
end
