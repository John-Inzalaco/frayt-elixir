defmodule FraytElixir.Notifications.MatchNotifications do
  alias FraytElixir.Shipment.{Match, MatchStop, MatchStateTransition, MatchStopStateTransition}
  alias FraytElixir.Accounts.{Shipper, User}
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.{Mailer, Email, Repo, Matches}
  alias FraytElixir.Notifications
  alias FraytElixir.Notifications.{Slack, DriverNotification}
  alias FraytElixir.Rating
  alias FraytElixir.Notifications.Zapier
  import FraytElixirWeb.DisplayFunctions

  require Logger

  def send_notifications(
        %Match{state: :driver_canceled, driver: driver} = match,
        %MatchStateTransition{notes: reason} = mst
      ) do
    Slack.send_match_message(
      match,
      "Driver #{full_name(driver)} has canceled. Cancellation reason: #{reason}",
      :danger,
      channel: :high_priority_dispatch
    )

    send_match_status_email(match, mst: mst)

    :ok
  end

  def send_notifications(
        %Match{
          state: state,
          shortcode: shortcode,
          driver: driver
        } = match,
        %MatchStateTransition{notes: reason} = mst
      )
      when state in [:canceled, :admin_canceled] do
    message =
      "Match ##{shortcode} has been canceled #{if is_nil(driver), do: " before a driver accepted it."}"

    send_shipper_push_notification(match, "Match canceled", message)

    Slack.send_match_message(
      match,
      build_match_canceled_slack_message(state, reason),
      :danger
    )

    send_match_status_email(match, mst: mst)

    with %Driver{user: %User{email: driver_email}} <- driver do
      DriverNotification.send_canceled_notification(driver, match)
      send_match_status_email(match, mst: mst, mailer_settings: %{to: driver_email})
    end

    :ok
  end

  def send_notifications(
        %Match{state: state} = match,
        %MatchStateTransition{from: :pending} = mst
      )
      when state in [:assigning_driver, :scheduled] do
    send_match_status_email(match, mst: mst)

    Task.start(fn -> Zapier.send_match_status(match) end)

    :ok
  end

  def send_notifications(
        %Match{
          state: :assigning_driver
        } = match,
        %Driver{} = driver
      ) do
    send_match_status_email(match, status_type: :preferred_driver_rejected, driver: driver)

    :ok
  end

  def send_notifications(
        %Match{
          state: :assigning_driver
        } = match,
        %MatchStateTransition{from: :scheduled} = mst
      ) do
    send_match_status_email(match, mst: mst)

    :ok
  end

  def send_notifications(
        %Match{
          state: :accepted,
          driver: driver
        } = match,
        mst
      ) do
    Slack.send_match_message(match, "has been accepted by Driver #{full_name(driver)}")

    send_match_status_email(match, mst: mst)

    :ok
  end

  def send_notifications(
        %Match{
          state: :arrived_at_pickup,
          shortcode: shortcode,
          driver: driver
        } = match,
        _
      ) do
    message = "Driver #{full_name(driver)} has arrived at pickup location for Match ##{shortcode}"

    send_shipper_push_notification(match, "Driver arrived at pickup", message)
    send_shipper_sms_notification(match, message)

    :ok
  end

  def send_notifications(
        %Match{
          state: :picked_up,
          shortcode: shortcode,
          driver: driver
        } = match,
        %MatchStopStateTransition{to: :arrived}
      ) do
    message =
      "Your Driver #{short_name(driver)} has arrived at the dropoff for Match ##{shortcode}"

    send_shipper_push_notification(match, "Driver arrived at dropoff", message)
    send_customer_sms_notifications(match, message)
    :ok
  end

  def send_notifications(
        %Match{
          state: :picked_up,
          shortcode: shortcode,
          driver: driver
        } = match,
        mst
      ) do
    message = "Your Driver #{short_name(driver)} has picked up Match ##{shortcode}"
    send_shipper_push_notification(match, "Driver has picked up", message)
    send_customer_sms_notifications(match, message)

    send_match_status_email(match, mst: mst)

    :ok
  end

  def send_notifications(
        %Match{
          state: :unable_to_pickup,
          driver: driver
        } = match,
        _mst
      ) do
    Slack.send_match_message(
      match,
      "Driver #{driver.first_name} #{driver.last_name} has marked a match as unable to pickup",
      :danger,
      channel: :dispatch_attempts
    )

    :ok
  end

  def send_notifications(%MatchStop{state: :undeliverable, index: index} = stop, _) do
    stop = stop |> Repo.preload(match: [:driver])

    Slack.send_match_message(
      stop.match,
      "Driver #{stop.match.driver.first_name} #{stop.match.driver.last_name} has marked match stop ##{index + 1} as undeliverable",
      :warning,
      channel: :dispatch_attempts
    )
  end

  def send_notifications(%Match{state: :completed} = match, mst) do
    send_match_status_email(match, mst: mst)

    if Matches.count_completed_matches_in_month(match.shipper.id, :shipper) == 1 do
      {:ok, nps_score} = Rating.create_nps_score(match.shipper.user.id, :shipper)

      Email.nps_score_email(%{
        email: match.shipper.user.email,
        name: match.shipper.first_name,
        shipper_id: match.shipper.id,
        nps_score_id: nps_score.id
      })
      |> Mailer.deliver_later()
    end

    :ok
  end

  def send_notifications(%MatchStop{state: :delivered, index: index} = stop, _) do
    stop = stop |> Repo.preload(match: [:driver])

    Slack.send_match_message(
      stop.match,
      "Driver #{stop.match.driver.first_name} #{stop.match.driver.last_name} has delivered cargo for match stop ##{index + 1}",
      :alert
    )
  end

  def send_notifications(_, _), do: :nothing_sent

  def send_driver_assigned_sms(%Match{driver: driver, shortcode: shortcode} = match),
    do:
      Notifications.send_notification(:sms, driver, match, %{
        body: "You have been assigned to Match ##{shortcode}"
      })

  def send_driver_assigned_push(%Match{driver: driver, shortcode: shortcode} = match) do
    Notifications.send_notification(:push, driver, match, %{
      title: "Match assigned",
      message: "You have been assigned to Match ##{shortcode}"
    })
  end

  def send_match_status_email(match, metadata \\ []) do
    mailer_settings =
      if Keyword.get(metadata, :mailer_settings, nil),
        do: Keyword.get(metadata, :mailer_settings),
        else: get_customer_match_mailer_settings(match)

    send_match_status_email(match, metadata, mailer_settings)
  end

  def send_match_status_email(match, metadata, %{
        to: to_email,
        cc: cc_emails,
        bcc: bcc_emails,
        close: close
      }),
      do:
        Email.match_status_email(match, metadata, %{
          to: to_email,
          cc: cc_emails,
          bcc: bcc_emails,
          subject: get_match_status_subject(match, metadata),
          close: close
        })
        |> Mailer.deliver_later()

  def send_match_status_email(match, metadata, mailer_settings),
    do:
      send_match_status_email(
        match,
        metadata,
        Map.merge(%{cc: [], bcc: [], close: nil}, mailer_settings)
      )

  defp get_customer_match_mailer_settings(
         %Match{
           state: state,
           match_stops: stops,
           shipper: %Shipper{user: %User{email: shipper_email}}
         } = match
       ) do
    bcc =
      case state in [:canceled, :admin_canceled, :picked_up] or
             Enum.any?(stops, &(&1.state == :arrived)) do
        true -> get_recipients(:email, match)
        _ -> []
      end

    bcc =
      if state == :completed do
        bcc ++ [{nil, "frayt.com+e9779ea710@invite.trustpilot.com"}]
      else
        bcc
      end

    %{
      to: shipper_email,
      bcc: bcc
    }
  end

  defp get_match_status_subject(
         %Match{} = match,
         %{
           status_type: :preferred_driver_rejected,
           driver: %Driver{first_name: first_name, last_name: last_name}
         }
       ),
       do: "#{first_name} #{last_name} Rejected" <> get_match_status_subject_identifier(match)

  defp get_match_status_subject(
         %Match{} = match,
         %{
           status_type: :preferred_driver_unassigned,
           driver: %Driver{first_name: first_name, last_name: last_name}
         }
       ),
       do: "#{first_name} #{last_name} Unassigned" <> get_match_status_subject_identifier(match)

  defp get_match_status_subject(%Match{state: state} = match, %{status_type: :stage}),
    do: display_stage(state) <> get_match_status_subject_identifier(match)

  defp get_match_status_subject(match, metadata) do
    status_type = Keyword.get(metadata, :status_type, :stage)
    driver = Keyword.get(metadata, :driver)
    get_match_status_subject(match, %{status_type: status_type, driver: driver})
  end

  defp get_match_status_subject_identifier(%Match{po: po, shortcode: shortcode})
       when not is_nil(po),
       do: " – #{po}/#{shortcode}"

  defp get_match_status_subject_identifier(%Match{shortcode: shortcode}),
    do: " – #{shortcode}"

  defp get_customer_phone(
         %Match{
           shipper: %Shipper{
             first_name: first_name,
             phone: phone
           }
         } = match
       ),
       do: [{first_name, phone}] ++ get_recipients(:phone, match)

  defp send_customer_sms_notifications(match, message),
    do:
      get_customer_phone(match)
      |> Enum.each(&send_sms_notification(elem(&1, 1), match, message))

  defp send_shipper_sms_notification(
         %Match{
           shipper: %Shipper{
             phone: phone
           }
         } = match,
         message
       ),
       do: send_sms_notification(phone, match, message)

  defp send_shipper_sms_notification(_, _), do: nil

  defp send_sms_notification(phone_number, match, message),
    do:
      Notifications.send_notification(:sms, match.shipper, match, %{
        body: message,
        to: phone_number
      })

  defp send_shipper_push_notification(
         %Match{
           shipper:
             %Shipper{
               one_signal_id: device_id
             } = shipper
         } = match,
         title,
         message
       )
       when not is_nil(device_id) do
    Notifications.send_notification(:push, shipper, match, %{
      title: title,
      message: message
    })
  end

  defp send_shipper_push_notification(_, _, _), do: nil

  defp get_cancellee(state) do
    case(state) do
      :canceled -> "the shipper"
      :admin_canceled -> "a Frayt admin"
      _ -> ""
    end
  end

  defp build_match_canceled_slack_message(
         state,
         reason
       )
       when is_atom(state) do
    state
    |> get_cancellee()
    |> build_match_canceled_slack_message(reason)
  end

  defp build_match_canceled_slack_message(user, reason) when reason not in [nil, ""],
    do: "#{build_match_canceled_slack_message(user, nil)} Cancellation reason: #{reason}"

  defp build_match_canceled_slack_message(user, _),
    do: "has been canceled by #{user}."

  defp get_recipients(
         field,
         %Match{
           match_stops: match_stops
         }
       ) do
    Enum.map(match_stops, fn %MatchStop{recipient: recipient} ->
      if recipient && recipient.notify do
        case field do
          :phone -> {recipient.name, format_phone(recipient.phone_number, :e164)}
          :email -> {recipient.name, recipient.email}
        end
      else
        {nil, nil}
      end
    end)
    |> Enum.filter(&elem(&1, 1))
  end
end
