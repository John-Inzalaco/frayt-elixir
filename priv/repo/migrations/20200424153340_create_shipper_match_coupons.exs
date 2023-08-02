defmodule FraytElixir.Repo.Migrations.CreateShipperMatchCoupons do
  use Ecto.Migration

  def change do
    create table(:shipper_match_coupons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :shipper_id, references(:shippers, type: :binary_id, on_delete: :nothing)
      add :match_id, references(:matches, type: :binary_id, on_delete: :nothing)
      add :coupon_id, references(:coupons, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:shipper_match_coupons, [:shipper_id])
    create index(:shipper_match_coupons, [:match_id])
    create index(:shipper_match_coupons, [:coupon_id])
  end
end
