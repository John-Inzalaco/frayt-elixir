defmodule FraytElixir.Repo.Migrations.AddExpectedTollAndTollFeePriceToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :expected_toll, :integer
      add :toll_fee_price, :integer
    end
  end
end
