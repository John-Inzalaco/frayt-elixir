defmodule FraytElixir.Repo.Migrations.AddTotalLoadFeePriceToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :total_load_fee_price, :integer
    end
  end
end
