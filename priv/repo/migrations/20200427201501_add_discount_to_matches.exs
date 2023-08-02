defmodule FraytElixir.Repo.Migrations.AddDiscountToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :price_discount, :integer, null: false, default: 0
    end
  end
end
