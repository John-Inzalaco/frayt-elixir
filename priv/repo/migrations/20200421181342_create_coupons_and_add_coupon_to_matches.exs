defmodule FraytElixir.Repo.Migrations.CreateCouponsAndAddCouponToMatches do
  use Ecto.Migration

  def change do
    create table(:coupons) do
      add :code, :string
      add :percentage, :integer

      timestamps()
    end

    alter table(:matches) do
      add :coupon_id, references(:coupons)
    end
  end
end
