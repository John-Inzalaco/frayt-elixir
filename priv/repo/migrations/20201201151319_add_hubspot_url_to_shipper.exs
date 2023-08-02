defmodule FraytElixir.Repo.Migrations.AddHubspotUrlToShipper do
  use Ecto.Migration

  def change do
    alter table(:shippers) do
      add :hubspot_id, :string
    end
  end
end
