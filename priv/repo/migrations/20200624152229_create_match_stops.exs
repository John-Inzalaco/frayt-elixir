defmodule FraytElixir.Repo.Migrations.CreateMatchStops do
  use Ecto.Migration

  def change do
    create table(:match_stops, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :weight, :integer
      add :height, :integer
      add :length, :integer
      add :pieces, :integer
      add :width, :integer
      add :load_fee_price, :integer
      add :has_load_fee, :boolean
      add :recipient_name, :string
      add :recipient_email, :string
      add :recipient_phone, :string
      add :destination_address_id, references(:addresses, on_delete: :nothing, type: :binary_id)
      add :match_id, references(:matches, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:match_stops, [:destination_address_id])
    create index(:match_stops, [:match_id])
  end
end
