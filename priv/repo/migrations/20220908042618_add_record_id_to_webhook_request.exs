defmodule FraytElixir.Repo.Migrations.AddRecordIdToWebhookRequest do
  use Ecto.Migration

  def change do
    alter table(:webhook_requests) do
      add :record_id, :binary_id
    end
  end
end
