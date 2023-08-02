defmodule FraytElixir.Repo.Migrations.CreateHiddenCustomers do
  use Ecto.Migration

  def change do
    create table(:hidden_customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :nothing)
      add :company_id, references(:companies, type: :binary_id, on_delete: :nothing)
      add :driver_id, references(:drivers, type: :binary_id, on_delete: :nothing)
      add :reason, :string

      timestamps()
    end

    create index(:hidden_customers, [:shipper_id])
    create index(:hidden_customers, [:company_id])
    create index(:hidden_customers, [:driver_id])
    create index(:hidden_customers, [:driver_id, :shipper_id], unique: true)
    create index(:hidden_customers, [:driver_id, :company_id], unique: true)
  end
end
