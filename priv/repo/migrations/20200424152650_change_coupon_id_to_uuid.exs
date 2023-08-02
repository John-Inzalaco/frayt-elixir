defmodule FraytElixir.Repo.Migrations.ChangeCouponIdToUuid do
  use Ecto.Migration

  def change do
    drop_if_exists table(:coupons)

    create table(:coupons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string
      add :percentage, :integer

      timestamps()
    end

    alter table(:matches) do
      add :coupon_id, references(:coupons, type: :binary_id, on_delete: :nothing)
    end
  end
end
