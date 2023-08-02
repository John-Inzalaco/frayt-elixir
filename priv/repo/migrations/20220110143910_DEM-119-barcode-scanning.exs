defmodule :"Elixir.FraytElixir.Repo.Migrations.DEM119BarcodeScanning" do
  use Ecto.Migration

  def change do
    alter table(:match_stop_items) do
      add :barcode, :string
      add :barcode_pickup_required, :boolean, default: false
      add :barcode_delivery_required, :boolean, default: false
    end

    create table(:barcodes_readings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string
      add :state, :string
      add :photo, :string
      add :barcode, :string, null: false
      add :match_stop_item_id, references(:match_stop_items, type: :binary_id)

      timestamps()
    end

    create unique_index(:barcodes_readings, [:type, :match_stop_item_id])
  end
end
