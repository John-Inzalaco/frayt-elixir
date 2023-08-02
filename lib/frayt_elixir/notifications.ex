defmodule FraytElixir.Notifications do
  @moduledoc """
  The Notifications context.
  """
  require Logger
  import Ecto.Query, warn: false
  import Ecto.Query, only: [from: 2]
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Repo
  alias Ecto.Multi

  alias FraytElixir.Notifications.{SentNotification, NotificationBatch, PushNotification}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Devices
  alias FraytElixir.Shipment.{DeliveryBatch, Match}
  alias FraytElixir.Accounts.{AdminUser, Shipper, Schedule}
  alias Phoenix.PubSub

  @frayt_phone_number Application.compile_env(:frayt_elixir, :frayt_phone_number)
  @sms_notification Application.compile_env(
                      :frayt_elixir,
                      :sms_notification,
                      &FraytElixir.Twilio.create/1
                    )

  @push_notification Application.compile_env(
                       :frayt_elixir,
                       :push_notification,
                       PushNotification
                     )

  @admin_max_notifications 15

  def get_max_daily_admin_mass_notifications, do: @admin_max_notifications

  def get_used_daily_admin_mass_notifications(admin, time_zone \\ "UTC") do
    beginning_of_day =
      time_zone
      |> Timex.now()
      |> Timex.beginning_of_day()

    from(nb in NotificationBatch,
      where: nb.inserted_at >= ^beginning_of_day and nb.admin_user_id == ^admin.id,
      select: count(nb)
    )
    |> Repo.one()
  end

  def send_notification_batch(admin, match, recipients, data) do
    {notifications_attrs, errors} =
      recipients
      |> Task.async_stream(fn to -> send_notification(%{}, :sms, to, match, data) end)
      |> Enum.into([], fn {:ok, res} -> res end)
      |> Enum.reduce({[], []}, fn res, {notifications, errors} ->
        case res do
          {:ok, attrs} -> {notifications ++ [attrs], errors}
          {:error, error, meta} -> {notifications, errors ++ [{error, meta}]}
        end
      end)

    with {code, value} = output <-
           %NotificationBatch{}
           |> NotificationBatch.changeset(%{
             match_id: match.id,
             admin_user_id: admin.id,
             sent_notifications: notifications_attrs
           })
           |> Repo.insert() do
      with {:ok, %NotificationBatch{} = batch} <- output do
        PubSub.broadcast!(
          FraytElixir.PubSub,
          "notification_batch:#{match.id}",
          {:new_notification_batch, batch}
        )
      end

      {code, value, errors}
    end
  end

  @doc """
  Send an SMS or push notification using OneSignal or Twilio services..

  ## Examples

    iex>  Notifications.send_notification(:push, driver, match, %{
      title: "Notification title",
      message: "Notification message."
    })
  """
  @spec send_notification(
          type :: :push | :sms,
          to :: Driver.t() | list(Driver.t()),
          subject ::
            Match.t() | Schedule.t() | DeliveryBatch.t() | AdminUser.t() | :is_test | atom(),
          data :: %{title: binary(), message: binary()}
        ) ::
          {:error, binary(), binary()}
          | {:error, binary()}
          | Multi.t()
          | {:ok, SentNotification.t()}

  def send_notification(:push, to, _subject, _data) when to == [],
    do: {:error, "Player ID not found"}

  def send_notification(:push, to, subject, data) when is_list(to) do
    data = Map.put(data, :data, put_subject_id(%{}, subject))
    driver_player_ids = Enum.map(to, &get_player_id(&1))

    with %{id: external_id} <- @push_notification.send(driver_player_ids, data) do
      Enum.reduce(to, Ecto.Multi.new(), fn driver, multi ->
        insert_sent_notification(multi, %{
          notification_type: :push,
          to: driver,
          subject: subject,
          external_id: external_id,
          data: data
        })
      end)
    end
  end

  def send_notification(type, to, subject, data),
    do: send_notification(nil, type, to, subject, data)

  def send_notification(into, :sms, to, subject, data) do
    data =
      %{
        from: @frayt_phone_number,
        to: get_phone_number(to)
      }
      |> Map.merge(data)

    with {:ok, %ExTwilio.Message{sid: external_id}} <-
           data |> Map.to_list() |> @sms_notification.() do
      insert_sent_notification(into, %{
        notification_type: :sms,
        to: to,
        subject: subject,
        external_id: external_id,
        data: data
      })
    end
    |> handle_into(into, phone_number: data.to, subject: subject, to: to, type: :sms)
  end

  def send_notification(into, :push, to, subject, data) do
    data = Map.put(data, :data, put_subject_id(%{}, subject))

    player_id = get_player_id(to)

    if player_id do
      with %OneSignal.Notification{id: external_id} <-
             @push_notification.send(player_id, data) do
        insert_sent_notification(into, %{
          notification_type: :push,
          to: to,
          subject: subject,
          external_id: external_id,
          data: data
        })
      end
    else
      {:error, "Player ID not found"}
    end
    |> handle_into(into, player_id: player_id, subject: subject, to: to, type: :push)
  end

  defp handle_into({:error, error, _code}, into, meta),
    do: handle_into({:error, error}, into, meta)

  defp handle_into({:error, error}, %Multi{} = multi, _meta) do
    Logger.error("sms_notification failed to send. Reason: #{inspect(error)}")

    multi
  end

  defp handle_into({:error, error}, _into, meta) do
    Logger.error("sms_notification failed to send. Reason: #{inspect(error)}")
    {:error, error, meta}
  end

  defp handle_into(%Multi{} = output, %Multi{}, _meta), do: output

  defp handle_into(output, _into, _meta), do: output

  defp insert_sent_notification(%Multi{} = multi, %{subject: subject, to: to} = attrs) do
    multi
    |> Multi.insert({:notification, "#{subject.id}_#{to.id}"}, fn changes ->
      attrs =
        case changes do
          %{notification_batch: batch} -> Map.put(attrs, :notification_batch_id, batch.id)
          _ -> attrs
        end

      sent_notification_changeset(attrs)
    end)
  end

  defp insert_sent_notification(%{} = into, attrs),
    do: {:ok, into |> Map.merge(sent_notification_attrs(attrs))}

  defp insert_sent_notification(nil, attrs),
    do:
      attrs
      |> sent_notification_changeset()
      |> Repo.insert()

  defp sent_notification_attrs(
         %{
           notification_type: type,
           to: to,
           subject: subject,
           data: data
         } = attrs
       ),
       do:
         attrs
         |> Map.take([:notification_type, :external_id, :notification_batch_id])
         |> put_recipient_contact(type, to, data)
         |> put_recipient_id(to)
         |> put_subject_id(subject)

  defp sent_notification_changeset(attrs),
    do: SentNotification.changeset(%SentNotification{}, sent_notification_attrs(attrs))

  defp put_recipient_id(attrs, %Driver{id: driver_id}), do: Map.put(attrs, :driver_id, driver_id)

  defp put_recipient_id(attrs, %Shipper{id: shipper_id}),
    do: Map.put(attrs, :shipper_id, shipper_id)

  defp put_subject_id(attrs, %Match{id: match_id}), do: Map.put(attrs, :match_id, match_id)

  defp put_subject_id(attrs, %Schedule{id: schedule_id}),
    do: Map.put(attrs, :schedule_id, schedule_id)

  defp put_subject_id(attrs, %DeliveryBatch{id: delivery_batch_id}),
    do: Map.put(attrs, :delivery_batch_id, delivery_batch_id)

  defp put_subject_id(attrs, %AdminUser{id: admin_id}),
    do: Map.put(attrs, :admin_user_id, admin_id)

  defp put_subject_id(attrs, :is_test),
    do: Map.put(attrs, :is_test, true)

  defp put_subject_id(attrs, term) when is_atom(term),
    do: Map.put(attrs, :notification, Atom.to_string(term))

  defp put_subject_id(attrs, atom),
    do: Map.put(attrs, :notification, atom)

  defp put_recipient_contact(attrs, :sms, _to, %{to: phone}),
    do: Map.put(attrs, :phone_number, phone)

  defp put_recipient_contact(attrs, :push, to, _data),
    do: Map.put(attrs, :device_id, get_player_id(to))

  defp get_phone_number(%Shipper{phone: phone}), do: phone

  defp get_phone_number(%Driver{phone_number: phone}),
    do: DisplayFunctions.format_phone(phone, :e164)

  defp get_player_id(%Shipper{one_signal_id: device_id}),
    do: device_id

  defp get_player_id(%Driver{default_device_id: default_device_id}) do
    case Devices.get_device!(default_device_id) do
      %{player_id: player_id} -> player_id
      _ -> nil
    end
  end
end
