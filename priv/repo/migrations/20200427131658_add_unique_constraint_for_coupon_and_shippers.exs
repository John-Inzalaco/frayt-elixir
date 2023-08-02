defmodule FraytElixir.Repo.Migrations.AddUniqueConstraintForCouponAndShippers do
  use Ecto.Migration

  def change do
    create unique_index(:shipper_match_coupons, [:coupon_id, :shipper_id])
  end
end
