defmodule FraytElixir.Repo.Migrations.MAR473AddParkingSpotRequiredFieldToMatchTable do
  use Ecto.Migration

  def change do
    alter table(:matches) do
      add :parking_spot_required, :boolean
    end
  end
end
