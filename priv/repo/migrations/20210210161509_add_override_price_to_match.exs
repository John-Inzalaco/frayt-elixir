defmodule FraytElixir.Repo.Migrations.AddOverridePriceToMatch do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :manual_price, :boolean
    end
  end
end
