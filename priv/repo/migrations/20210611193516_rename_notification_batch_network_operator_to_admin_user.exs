defmodule FraytElixir.Repo.Migrations.RenameNotificationBatchNetworkOperatorToAdminUser do
  use Ecto.Migration

  def change do
    drop index(:notification_batches, [:network_operator_id])

    alter table(:notification_batches) do
      add :admin_user_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
      remove :network_operator_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end

    create index(:notification_batches, [:admin_user_id])
  end
end
