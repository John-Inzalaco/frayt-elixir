defmodule FraytElixir.Repo.Migrations.AddCountryToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :country, :string
    end
  end
end
