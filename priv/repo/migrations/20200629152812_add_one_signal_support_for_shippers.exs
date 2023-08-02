defmodule FraytElixir.Repo.Migrations.AddOneSignalSupportForShippers do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :one_signal_id, :string
    end

    alter table(:sent_notifications) do
      add :shipper_id, references(:shippers, on_delete: :nothing, type: :binary_id)
    end

    create index(:sent_notifications, [:shipper_id])
  end
end
