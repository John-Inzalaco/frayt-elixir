defmodule FraytElixir.Notifications.MatchNotificationsTest do
  use FraytElixir.DataCase
  use Bamboo.Test

  alias FraytElixir.Shipment.{Match, MatchStop}
  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Notifications.{SentNotification, MatchNotifications}
  alias FraytElixir.Email
  alias FraytElixir.Test.FakeSlack
  import FraytElixirWeb.DisplayFunctions
  import FraytElixir.Factory

  setup do
    FakeSlack.clear_messages()
  end

  describe "send_notifications/2 :driver_canceled" do
    test "sends a slack message" do
      match = insert(:accepted_match, state: :driver_canceled)

      mst =
        insert(:match_state_transition,
          from: :accepted,
          to: :driver_canceled,
          notes: "some reason",
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert [{_, message}] = FakeSlack.get_messages("#test-high-priority-dispatch")
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, "canceled")
      assert String.contains?(message, "some reason")
    end

    test "sends shipper email" do
      %Match{
        shortcode: shortcode,
        shipper: %{user: %{email: shipper_email}}
      } = match = insert(:accepted_match, state: :driver_canceled)

      mst =
        insert(:match_state_transition,
          from: :accepted,
          to: :driver_canceled,
          notes: "some reason",
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      expected_email_1 =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          subject: "Driver Canceled – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_email_1)
      assert expected_email_1.to == shipper_email
      assert expected_email_1.html_body =~ "Rerouting Drivers"

      assert expected_email_1.html_body =~
               "We are rerouting drivers to find the closest match. A new driver will be on their way to pick up your Match ##{shortcode} shortly."
    end
  end

  describe "send_notifications/2 :canceled" do
    test "sends a slack message" do
      match = insert(:accepted_match, state: :canceled)

      mst =
        insert(:match_state_transition,
          from: :pending,
          to: :canceled,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert [{_, message}] = FakeSlack.get_messages("#test-dispatch")
      assert message =~ match.shortcode
      assert message =~ "canceled"
      assert message =~ "the shipper"
    end
  end

  describe "send_notifications/2 :admin_canceled" do
    test "sends a slack message" do
      match = insert(:match, state: :admin_canceled)

      mst =
        insert(:match_state_transition,
          from: :pending,
          to: :admin_canceled,
          notes: "some random reason",
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert [{_, message}] = FakeSlack.get_messages("#test-dispatch")

      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, "canceled")
      assert String.contains?(message, "a Frayt admin")
      assert String.contains?(message, "Cancellation reason: some random reason")
    end

    test "sends a slack message without cancel reason" do
      match = insert(:match, state: :admin_canceled)

      mst =
        insert(:match_state_transition,
          from: :pending,
          to: :admin_canceled,
          match: match
        )

      FakeSlack.clear_messages()

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert [{_, message}] = FakeSlack.get_messages("#test-dispatch")
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, "canceled")
      refute String.contains?(message, "Cancellation reason:")
    end

    test "sends push notifications if shipper has one_signal_id and driver exists" do
      driver = insert(:driver)
      %{default_device: default_device} = driver = set_driver_default_device(driver)

      match =
        insert(:arrived_at_pickup_match,
          shortcode: "F0CBE109",
          driver: driver,
          shipper: build(:shipper, one_signal_id: "12345"),
          state: :admin_canceled
        )

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :admin_canceled,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)
      assert Repo.get_by!(SentNotification, device_id: "12345")
      assert Repo.get_by!(SentNotification, device_id: default_device.player_id)
    end

    test "sends emails if shipper and driver exist" do
      %Match{
        shortcode: shortcode,
        po: po,
        driver: driver,
        shipper: shipper,
        match_stops: [%{recipient: %{email: recipient_email, name: recipient_name}}]
      } =
        match =
        insert(:match,
          shortcode: "F0CBE109",
          state: :admin_canceled,
          shipper: build(:shipper, user: build(:user, email: "shipper@email.co")),
          driver: build(:driver, user: build(:user, email: "driver@email.co"))
        )

      mst =
        insert(:match_state_transition,
          from: :accepted,
          to: :admin_canceled,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      expected_email_1 =
        Email.match_status_email(match, [mst: mst], %{
          to: "shipper@email.co",
          bcc: [{recipient_name, recipient_email}],
          subject: "Admin Canceled – #{po}/#{shortcode}"
        })

      assert_delivered_email(expected_email_1)
      assert expected_email_1.to == shipper.user.email
      assert expected_email_1.html_body =~ "Admin Canceled"
      assert expected_email_1.html_body =~ "Match ##{shortcode} has been canceled."

      expected_email_2 =
        Email.match_status_email(match, [mst: mst], %{
          to: "driver@email.co",
          subject: "Admin Canceled – #{po}/#{shortcode}"
        })

      assert_delivered_email(expected_email_2)
      assert expected_email_2.to == driver.user.email
      assert expected_email_2.html_body =~ "Admin Canceled"
      assert expected_email_2.html_body =~ "Match ##{shortcode} has been canceled."
    end

    test "sends only one email if driver doesn't exist" do
      %Match{
        shortcode: shortcode,
        po: po,
        shipper: shipper,
        match_stops: [%{recipient: %{email: recipient_email, name: recipient_name}}]
      } =
        match =
        insert(:match,
          shortcode: "F0CBE109",
          state: :admin_canceled,
          shipper: build(:shipper, user: build(:user, email: "shipper@email.co")),
          driver: nil
        )

      mst =
        insert(:match_state_transition,
          from: :assigning_driver,
          to: :admin_canceled,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      expected_email =
        Email.match_status_email(match, [mst: mst], %{
          to: "shipper@email.co",
          bcc: [{recipient_name, recipient_email}],
          subject: "Admin Canceled – #{po}/#{shortcode}"
        })

      assert_delivered_email(expected_email)
      assert expected_email.to == shipper.user.email
      assert expected_email.html_body =~ "Admin Canceled"

      assert expected_email.html_body =~
               "Match ##{shortcode} has been canceled before a driver accepted it."
    end
  end

  describe "send_notifications/2 :accepted" do
    test "sends slack notification to #dispatch channel" do
      match = insert(:accepted_match)

      mst =
        insert(:match_state_transition,
          from: :assigning_driver,
          to: :accepted,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert [{_, message}] = FakeSlack.get_messages("#test-dispatch")
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, match.driver.first_name)
    end

    test "sends email notification to shipper" do
      %Match{
        shipper: %{user: %{email: shipper_email}},
        driver: driver
      } = match = insert(:accepted_match)

      mst =
        insert(:match_state_transition,
          from: :assigning_driver,
          to: :accepted,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      expected_email =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          subject: "Accepted – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_email)
      assert expected_email.to == shipper_email
      assert expected_email.html_body =~ "Driver Assigned"
      assert expected_email.html_body =~ "driver #{driver.first_name}"
      assert expected_email.html_body =~ match.origin_address.formatted_address
    end
  end

  describe "send_notifications/2 :assigning_driver" do
    test "from :scheduled sends sends email to shipper" do
      %Match{
        origin_address: origin_address,
        shipper: %{user: %{email: shipper_email}}
      } =
        match =
        insert(:match,
          scheduled: true,
          pickup_at: DateTime.utc_now() |> DateTime.add(1 * 3600),
          state: :assigning_driver
        )

      mst =
        insert(:match_state_transition,
          from: :scheduled,
          to: :assigning_driver,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      expected_email =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          subject: "Assigning Driver – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_email)
      assert expected_email.to == shipper_email
      assert expected_email.bcc == [Application.get_env(:frayt_elixir, :notifications_email)]
      assert expected_email.html_body =~ "Confirmation"
      assert expected_email.html_body =~ "#{origin_address.formatted_address}"
    end
  end

  describe "send_notifications/2 :arrived_at_pickup" do
    test "sends push notification to shipper" do
      match = insert(:arrived_at_pickup_match, shipper: build(:shipper, one_signal_id: "12345"))

      mst =
        insert(:match_state_transition,
          from: :en_route_to_pickup,
          to: :arrived_at_pickup,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert Repo.get_by!(SentNotification, device_id: "12345")
    end

    test "does only sends sms if shipper doesn't have one signal id" do
      match = insert(:arrived_at_pickup_match, shipper: build(:shipper, one_signal_id: nil))

      mst =
        insert(:match_state_transition,
          from: :en_route_to_pickup,
          to: :arrived_at_pickup,
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert SentNotification
             |> Repo.all()
             |> Enum.count() == 1
    end
  end

  describe "send_notifications/2 :unable_to_pickup" do
    test "sends a slack message" do
      match = insert(:match, state: :unable_to_pickup)

      mst =
        insert(:match_state_transition,
          notes: "some reason",
          match: match
        )

      assert :ok = MatchNotifications.send_notifications(match, mst)

      assert [{channel, message}] = FakeSlack.get_messages()
      assert channel == "#test-dispatch-attempts"
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, "unable to pickup")
    end
  end

  describe "send_notifications/2 :undeliverable" do
    test "sends a slack message" do
      %{match_stops: [stop]} =
        match =
        insert(:signed_match, %{
          match_stops: [build(:undeliverable_match_stop, index: 0)]
        })

      mst =
        insert(:match_state_transition,
          notes: "some reason",
          match: match
        )

      MatchNotifications.send_notifications(stop, mst)

      assert [{channel, message}] = FakeSlack.get_messages()
      assert channel == "#test-dispatch-attempts"
      assert String.contains?(message, match.shortcode)
      assert String.contains?(message, "undeliverable")
    end
  end

  describe "send_notifications/2 :picked_up" do
    test "picking up sends push notification if shipper has one_signal_id" do
      match = insert(:picked_up_match, shipper: build(:shipper, one_signal_id: "12345"))

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      assert Repo.get_by!(SentNotification, device_id: "12345")
    end

    test "doesn't send push notification if shipper doesn't have one_signal_id" do
      match = insert(:picked_up_match, shipper: build(:shipper, one_signal_id: nil))

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      assert from(sn in SentNotification, where: sn.notification_type == "push")
             |> Repo.all()
             |> Enum.count() == 0
    end

    test "sends email to shipper and recipients" do
      %{
        driver: driver,
        origin_address: origin_address,
        shipper: %{user: %{email: shipper_email}},
        match_stops: [
          %MatchStop{recipient: %{email: recipient_email, name: recipient_name}}
        ]
      } = match = insert(:picked_up_match, match_stops: build_match_stops_with_items([:pending]))

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      expected_email =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          bcc: [{recipient_name, recipient_email}],
          subject: "Picked Up – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_email)
      assert expected_email.to == shipper_email
      assert {recipient_name, recipient_email} in expected_email.bcc
      assert expected_email.html_body =~ "Cargo Picked Up"
      assert expected_email.html_body =~ "driver #{driver.first_name}"
      assert expected_email.html_body =~ origin_address.formatted_address
    end

    test "picking up sends sms to shipper and recipients with phone numbers" do
      %{
        id: match_id,
        shipper: %{phone: shipper_phone}
      } =
        match =
        insert(:picked_up_match,
          match_stops: [
            build(:match_stop, recipient: insert(:contact, phone_number: "+15134020001")),
            build(:match_stop, recipient: insert(:contact, phone_number: "+15134020002"))
          ]
        )

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      assert sms_notifications =
               Repo.all(
                 from sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
               )

      assert Enum.count(sms_notifications) == 3
      assert "+15134020001" in (sms_notifications |> Enum.map(& &1.phone_number))
      assert "+15134020002" in (sms_notifications |> Enum.map(& &1.phone_number))
      assert shipper_phone in (sms_notifications |> Enum.map(& &1.phone_number))

      assert sms_notifications
             |> Enum.all?(fn %SentNotification{external_id: external_id} ->
               String.length(external_id) > 0
             end)
    end

    test "picking up sends email to just shipper if no recipient" do
      %{
        driver: driver,
        origin_address: origin_address,
        shipper: %{user: %{email: shipper_email}}
      } =
        match =
        insert(:picked_up_match,
          match_stops: [
            build(:match_stop,
              recipient: nil,
              destination_address: build(:address)
            )
          ]
        )

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      expected_email =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          subject: "Picked Up – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_email)
      assert expected_email.to == shipper_email
      assert expected_email.html_body =~ "Cargo Picked Up"
      assert expected_email.html_body =~ "driver #{driver.first_name}"
      assert expected_email.html_body =~ origin_address.formatted_address

      # Bamboo gives us no better way to assert that no other emails were sent
      assert_no_emails_delivered()
    end

    test "picking up does not send email or phone number to recipient if notify_recipient is false" do
      %{
        shipper: %{user: %{email: shipper_email}},
        id: match_id
      } =
        match =
        insert(:picked_up_match,
          match_stops: [
            build(:match_stop,
              recipient: insert(:contact, notify: false, phone_number: "+15134020000")
            )
          ]
        )

      mst =
        insert(:match_state_transition,
          from: :arrived_at_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      expected_recipient_email =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          subject: "Picked Up – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_recipient_email)

      assert sms_notifications =
               Repo.all(
                 from sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
               )

      refute "+15134020000" in (sms_notifications |> Enum.map(& &1.phone_number))
    end
  end

  describe "send_notifications/2 :arrived_at_dropoff" do
    test "sends sms to shipper" do
      %{
        id: match_id,
        shipper: %{phone: shipper_phone},
        match_stops: [%{recipient: %{phone_number: recipient_phone}}]
      } = %Match{match_stops: [stop]} = match = insert(:arrived_at_dropoff_match)

      recipient_phone = ExPhoneNumber.format(recipient_phone, :e164)

      msst =
        insert(:match_stop_state_transition,
          from: :en_route,
          to: :arrived,
          match_stop: stop
        )

      MatchNotifications.send_notifications(match, msst)

      assert sms_notifications =
               Repo.all(
                 from sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
               )

      assert Enum.count(sms_notifications) == 2
      assert shipper_phone in (sms_notifications |> Enum.map(& &1.phone_number))
      assert recipient_phone in (sms_notifications |> Enum.map(& &1.phone_number))

      assert sms_notifications
             |> Enum.all?(fn %SentNotification{external_id: external_id} ->
               String.length(external_id) > 0
             end)
    end

    test "picking up does not send email or phone number to recipient if notify is false" do
      %{
        id: match_id
      } =
        match =
        insert(:arrived_at_pickup_match,
          match_stops: [
            build(:match_stop,
              recipient: insert(:contact, notify: false, phone_number: "+15134020000")
            )
          ]
        )

      mst =
        insert(:match_state_transition,
          from: :en_route_to_pickup,
          to: :picked_up,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      assert sms_notifications =
               Repo.all(
                 from sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
               )

      refute "+15134020000" in (sms_notifications |> Enum.map(& &1.phone_number))
    end
  end

  describe "send_notifications/2 :delivered" do
    test "sends email to shipper" do
      %PaymentTransaction{
        match:
          %{
            shortcode: shortcode,
            shipper: %{user: %{email: shipper_email}},
            driver: %{first_name: driver_first_name},
            match_stops: [
              %{}
            ]
          } = match
      } =
        insert(:payment_transaction,
          transaction_type: :authorize,
          status: "succeeded",
          match:
            build(:match,
              amount_charged: 2000,
              driver_total_pay: 1500,
              match_stops: [build(:match_stop)],
              shipper: build(:shipper, one_signal_id: "32653", user: build(:user)),
              driver: build(:driver_with_wallet),
              state: :completed
            )
        )

      mst =
        insert(:match_state_transition,
          from: :picked_up,
          to: :completed,
          match: match
        )

      MatchNotifications.send_notifications(match, mst)

      expected_email =
        Email.match_status_email(match, [mst: mst], %{
          to: shipper_email,
          bcc: [{nil, "frayt.com+e9779ea710@invite.trustpilot.com"}],
          subject: "Completed – #{match.po}/#{match.shortcode}"
        })

      assert_delivered_email(expected_email)
      assert expected_email.to == shipper_email
      assert expected_email.html_body =~ "Match Receipt"
      assert expected_email.html_body =~ "driver, #{driver_first_name}"
      assert expected_email.html_body =~ "##{shortcode}"
      assert expected_email.html_body =~ "$20.00"
    end
  end

  describe "send_driver_assigned_sms/1" do
    test "sends sms to driver" do
      %{
        id: match_id,
        driver: %{phone_number: phone}
      } = match = insert(:accepted_match)

      MatchNotifications.send_driver_assigned_sms(match)

      assert sms_notifications =
               Repo.all(
                 from sn in SentNotification,
                   where: sn.match_id == ^match_id and sn.notification_type == "sms"
               )

      assert Enum.count(sms_notifications) == 1
      assert format_phone(phone, :e164) in (sms_notifications |> Enum.map(& &1.phone_number))
    end
  end
end
