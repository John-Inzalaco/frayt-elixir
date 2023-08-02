defmodule FraytElixir.Repo.Migrations.AddOldUserIdToUsersAndRemoveOldDriverAndShipper do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :old_user_id, :text
    end

    alter table(:shippers) do
      remove :old_shipper_id, :text
    end

    alter table(:drivers) do
      remove :old_driver_id, :text
    end
  end
end
