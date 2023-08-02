defmodule FraytElixir.Repo.Migrations.AddTipToMatchStop do
  use Ecto.Migration

  def change do
    alter table(:match_stops) do
      add :tip_price, :integer
    end
  end
end
