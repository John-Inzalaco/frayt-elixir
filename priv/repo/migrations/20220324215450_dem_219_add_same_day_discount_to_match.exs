defmodule FraytElixir.Repo.Migrations.Dem219AddSameDayDiscountToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :same_day_discount, :float
    end
  end
end
