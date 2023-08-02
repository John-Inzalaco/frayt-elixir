defmodule FraytElixir.Repo.Migrations.RemoveNullConstraintFromBarcode do
  use Ecto.Migration

  def change do
    rename table(:barcodes_readings), to: table(:barcode_readings)

    alter table(:barcode_readings) do
      modify :barcode, :string, null: true, from: :string
    end

    drop unique_index(:barcodes_readings, [:type, :match_stop_item_id])
    create unique_index(:barcode_readings, [:type, :match_stop_item_id])
  end
end
