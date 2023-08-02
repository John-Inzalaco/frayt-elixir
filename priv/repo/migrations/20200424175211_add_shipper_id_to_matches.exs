defmodule FraytElixir.Repo.Migrations.AddShipperIdToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :coupon_id
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :nothing)
    end
  end
end
