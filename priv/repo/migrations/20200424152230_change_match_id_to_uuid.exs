defmodule FraytElixir.Repo.Migrations.ChangeMatchIdToUuid do
  use Ecto.Migration

  def change do
    create table(:matches, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :distance, :float
      add :base_price, :integer
      add :load_fee_price, :integer
      add :alert_headline, :string
      add :alert_description, :string
      add :markup, :boolean, default: false, null: false
      add :weight, :integer
      add :scheduled, :boolean
      add :pickup_at, :utc_datetime
      add :dropoff_at, :utc_datetime
      add :width, :integer
      add :height, :integer
      add :length, :integer
      add :pieces, :integer
      add :has_load_fee, :boolean, default: false
      add :pickup_notes, :string
      add :delivery_notes, :string
      add :description, :text
      add :po, :string
      add :self_recipient, :boolean, default: false
      add :recipient_name, :string
      add :recipient_email, :string
      add :recipient_phone, :string

      add :origin_address_id, references(:addresses, type: :binary_id)
      add :destination_address_id, references(:addresses, type: :binary_id)

      timestamps()
    end
  end
end
