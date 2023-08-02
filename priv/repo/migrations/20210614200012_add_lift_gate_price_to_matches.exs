defmodule FraytElixir.Repo.Migrations.AddLiftGatePriceToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :lift_gate_price, :integer
    end
  end
end
