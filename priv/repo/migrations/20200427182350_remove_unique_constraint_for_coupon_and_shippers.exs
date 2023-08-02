defmodule FraytElixir.Repo.Migrations.RemoveUniqueConstraintForCouponAndShippers do
  use Ecto.Migration

  def change do
    drop unique_index(:shipper_match_coupons, [:coupon_id, :shipper_id])
  end
end
