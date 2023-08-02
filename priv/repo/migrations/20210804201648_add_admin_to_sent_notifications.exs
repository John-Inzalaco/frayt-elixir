defmodule FraytElixir.Repo.Migrations.AddAdminToSentNotifications do
  use Ecto.Migration

  def change do
    alter table(:sent_notifications) do
      add :admin_user_id, references(:admin_users, type: :binary_id, on_delete: :nothing)
    end
  end
end
