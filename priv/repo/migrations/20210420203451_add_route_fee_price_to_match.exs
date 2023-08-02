defmodule FraytElixir.Repo.Migrations.AddRouteFeePriceToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :route_fee_price, :integer
    end
  end
end
