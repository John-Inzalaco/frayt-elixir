defmodule FraytElixir.Repo.Migrations.AddOldShipperIdToShippers do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :old_shipper_id, :text
    end
  end
end
