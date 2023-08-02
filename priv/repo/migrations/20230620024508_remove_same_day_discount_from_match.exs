defmodule FraytElixir.Repo.Migrations.RemoveSameDayDiscountFromMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      remove :same_day_discount, :float, default: 1.0
    end
  end
end
