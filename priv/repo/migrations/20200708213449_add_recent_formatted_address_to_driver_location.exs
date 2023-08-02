defmodule FraytElixir.Repo.Migrations.AddRecentFormattedAddressToDriverLocation do
  use Ecto.Migration

  def change do
    alter table(:driver_locations) do
      add :formatted_address, :string
    end
  end
end
