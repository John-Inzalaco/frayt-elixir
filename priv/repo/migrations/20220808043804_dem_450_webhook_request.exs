defmodule FraytElixir.Repo.Migrations.DEM450WebhookRequest do
  use Ecto.Migration

  def change do
    create table(:webhook_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :company_id, references(:companies, type: :binary_id)
      add :payload, :map, null: false
      add :webhook_url, :string, null: false
      add :response, :text
      add :state, :string, null: false, default: "pending"
      add :completed_at, :utc_datetime_usec
      add :sent_at, :utc_datetime_usec
      add :webhook_type, :string, null: false
      timestamps()
    end
  end
end
