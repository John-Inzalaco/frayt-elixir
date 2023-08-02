defmodule FraytElixir.Notifications.NotificationBatch do
  use FraytElixir.Schema
  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Accounts.AdminUser
  alias FraytElixir.Shipment.Match

  schema "notification_batches" do
    belongs_to :admin_user, AdminUser
    belongs_to :match, Match
    has_many :sent_notifications, SentNotification

    timestamps()
  end

  @doc false
  def changeset(notification_batch, attrs) do
    notification_batch
    |> cast(attrs, [:admin_user_id, :match_id])
    |> cast_assoc(:sent_notifications, required: true)
    |> validate_required([:admin_user_id, :match_id])
    |> validate_assoc_length(:sent_notifications, min: 1)
  end
end
