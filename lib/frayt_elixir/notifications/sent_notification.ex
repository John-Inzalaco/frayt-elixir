defmodule FraytElixir.Notifications.SentNotification do
  use FraytElixir.Schema

  alias FraytElixir.Shipment.{DeliveryBatch, Match}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Notifications.{NotificationType, NotificationBatch}
  alias FraytElixir.Accounts.{AdminUser, Schedule, Shipper}

  schema "sent_notifications" do
    belongs_to :driver, Driver
    belongs_to :shipper, Shipper
    belongs_to :match, Match
    belongs_to :schedule, Schedule
    belongs_to :delivery_batch, DeliveryBatch
    belongs_to :notification_batch, NotificationBatch
    belongs_to :admin_user, AdminUser
    field :is_test, :boolean, virtual: true
    field :notification, :string, virtual: true
    field :phone_number, :string
    field :device_id, :string
    field :notification_type, NotificationType
    field :external_id, :string

    timestamps()
  end

  @doc false
  def changeset(sent_notification, attrs) do
    sent_notification
    |> cast(attrs, [
      :driver_id,
      :shipper_id,
      :match_id,
      :schedule_id,
      :delivery_batch_id,
      :notification_batch_id,
      :external_id,
      :phone_number,
      :device_id,
      :notification_type,
      :admin_user_id,
      :is_test,
      :notification
    ])
    |> validate_one_of_present([:driver_id, :shipper_id])
    |> validate_one_of_present([
      :is_test,
      :notification,
      :match_id,
      :schedule_id,
      :delivery_batch_id,
      :admin_user_id
    ])
  end
end
