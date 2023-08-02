defmodule FraytElixir.Repo.Migrations.AddBasePriceToMatchStops do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :base_price, :integer
    end

    rename table(:matches), :base_price, to: :total_base_price
  end
end
