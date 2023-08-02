defmodule FraytElixir.Repo.Migrations.AddConditionalFieldsToCoupons do
  use Ecto.Migration

  def change do
    alter table(:coupons) do
      add :start_date, :utc_datetime
      add :end_date, :utc_datetime
      add :use_limit, :integer
      add :price_minimum, :integer
      add :price_maximum, :integer
      add :fixed_discount, :integer
    end
  end
end
