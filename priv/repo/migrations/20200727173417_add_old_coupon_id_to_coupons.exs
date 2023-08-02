defmodule FraytElixir.Repo.Migrations.AddOldCouponIdToCoupons do
  use Ecto.Migration

  def change do
    alter table(:coupons) do
      add :old_coupon_id, :text
    end
  end
end
