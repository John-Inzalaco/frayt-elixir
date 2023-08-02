defmodule FraytElixir.Repo.Migrations.AddTotalTipPriceToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :total_tip_price, :integer
    end
  end
end
