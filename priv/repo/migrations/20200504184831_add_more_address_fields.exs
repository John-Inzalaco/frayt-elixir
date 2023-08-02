defmodule FraytElixir.Repo.Migrations.AddMoreAddressFields do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :address2, :string
      add :city, :string
      add :state, :string
      add :zip, :string
    end

    alter table(:locations) do
      add :address_id, references(:addresses, type: :binary_id, on_delete: :nothing)
    end

    create index(:locations, [:address_id])
  end
end
