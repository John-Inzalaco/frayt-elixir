defmodule FraytElixir.Repo.Migrations.AddDiscountMaximumToCoupon do
  use Ecto.Migration

  def change do
    alter table(:coupons) do
      add :discount_maximum, :integer
      remove :fixed_discount, :integer
    end
  end
end
