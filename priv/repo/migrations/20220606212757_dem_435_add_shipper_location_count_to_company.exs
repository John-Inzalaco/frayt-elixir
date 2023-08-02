defmodule FraytElixir.Repo.Migrations.DEM435AddShipperLocationCountToCompany do
  use Ecto.Migration

  def change do
    alter table(:companies) do
      add_if_not_exists(:location_count, :integer, default: 0, null: false)
      add_if_not_exists(:shipper_count, :integer, default: 0, null: false)
    end
  end
end
