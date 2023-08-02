defmodule FraytElixir.Repo.Migrations.AddFinalPriceToMatches do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :amount_charged, :integer
    end
  end
end
