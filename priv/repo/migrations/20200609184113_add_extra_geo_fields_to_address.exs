defmodule FraytElixir.Repo.Migrations.AddExtraGeoFieldsToAddress do
  use Ecto.Migration

  def change do
    alter table(:addresses) do
      add :county, :string
      add :neighborhood, :string
      add :formatted_address, :string
    end
  end
end
