defmodule FraytElixir.Repo.Migrations.AddCountryCodeToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :country_code, :string
    end
  end
end
