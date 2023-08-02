defmodule FraytElixir.Repo.Migrations.AddPhoneNumberAndTypeToSentNotification do
  use Ecto.Migration

  def change do
    alter table(:sent_notifications) do
      add :phone_number, :string
      add :device_id, :string
      add :notification_type, :string, default: "push"
    end
  end
end
