defmodule FraytElixir.NotificationsTest do
  use FraytElixir.DataCase

  alias FraytElixir.Notifications
  alias FraytElixir.Repo
  alias Notifications.{SentNotification, NotificationBatch}
  alias Ecto.Multi
  alias Phoenix.PubSub

  describe "get_used_daily_admin_mass_notifications" do
    test "gets number of used notifications" do
      net_op = insert(:network_operator)

      insert_list(3, :notification_batch, admin_user: net_op)
      insert(:notification_batch)
      insert(:notification_batch, admin_user: net_op, inserted_at: ~N[2020-01-01 00:00:00])

      assert 3 == Notifications.get_used_daily_admin_mass_notifications(net_op, "UTC")
    end
  end

  describe "send_notification_batch" do
    test "sends a batch of notifications" do
      drivers = insert_list(3, :driver)
      %{id: net_op_id} = net_op = insert(:network_operator)
      %{id: match_id} = match = insert(:match)

      :ok = PubSub.subscribe(FraytElixir.PubSub, "notification_batch:#{match_id}")

      assert {:ok,
              %NotificationBatch{
                id: batch_id,
                match_id: ^match_id,
                admin_user_id: ^net_op_id,
                sent_notifications: sent_notifications
              },
              []} =
               Notifications.send_notification_batch(net_op, match, drivers, %{
                 body: "test title"
               })

      sent_notifications
      |> Enum.each(fn sent_notification ->
        assert %SentNotification{
                 notification_batch_id: ^batch_id,
                 match_id: ^match_id,
                 driver_id: driver_id
               } = sent_notification

        assert driver_id in (drivers |> Enum.map(& &1.id))
      end)

      assert_receive {:new_notification_batch, %NotificationBatch{id: ^batch_id}}
    end

    test "collects errors and sends notifications" do
      %{id: valid_id} = valid = insert(:driver)
      invalid = insert(:shipper, phone: "000")
      %{id: net_op_id} = net_op = insert(:network_operator)
      %{id: match_id} = match = insert(:match)

      assert {:ok,
              %NotificationBatch{
                match_id: ^match_id,
                admin_user_id: ^net_op_id,
                sent_notifications: [
                  %SentNotification{driver_id: ^valid_id}
                ]
              },
              [
                {%{"message" => _, "status" => 400},
                 phone_number: "000", subject: ^match, to: ^invalid, type: :sms}
              ]} =
               Notifications.send_notification_batch(net_op, match, [valid, invalid], %{
                 body: "test title"
               })
    end
  end

  describe "send_notification" do
    test "sends push notification" do
      driver = insert(:driver_with_wallet)
      device = insert(:device, driver_id: driver.id, player_id: "player_id")
      %{id: driver_id} = driver = set_driver_default_device(driver, device)
      %{id: match_id} = match = insert(:match)

      assert {:ok,
              %SentNotification{
                notification_type: :push,
                driver_id: ^driver_id,
                match_id: ^match_id,
                device_id: "player_id",
                external_id: "27d90540-e270-41a7-b9d2-ef3c26c1613d",
                phone_number: nil
              }} =
               Notifications.send_notification(:push, driver, match, %{
                 title: "test title",
                 message: "test message"
               })
    end

    test "sends push notification async" do
      driver1 = insert(:driver_with_wallet)
      driver2 = insert(:driver_with_wallet)
      driver3 = insert(:driver_with_wallet)

      device1 = insert(:device, driver_id: driver1.id, player_id: "player_id1")
      device2 = insert(:device, driver_id: driver2.id, player_id: "player_id2")
      device3 = insert(:device, driver_id: driver3.id, player_id: "player_id3")

      driver_1 = set_driver_default_device(driver1, device1)
      driver_2 = set_driver_default_device(driver2, device2)
      driver_3 = set_driver_default_device(driver3, device3)

      %{id: _match_id} = match = insert(:match)

      assert %Ecto.Multi{operations: operations} =
               Notifications.send_notification(:push, [driver_1, driver_2, driver_3], match, %{
                 title: "test title",
                 message: "test message"
               })

      assert length(operations) == 3
    end

    test "sends sms notification to shipper" do
      %{id: shipper_id} = shipper = insert(:shipper, phone: "1234567890")
      %{id: match_id} = match = insert(:match)

      assert {:ok,
              %SentNotification{
                notification_type: :sms,
                shipper_id: ^shipper_id,
                match_id: ^match_id,
                phone_number: "1234567890",
                external_id: "SMa966f710be1843f3a8f9287b3d913e59",
                device_id: nil,
                driver_id: nil
              }} = Notifications.send_notification(:sms, shipper, match, %{body: "test message"})
    end

    test "sends sms notification to driver" do
      %{id: driver_id} = driver = insert(:driver, phone_number: "+15134021234")

      %{id: match_id} = match = insert(:match)

      assert {:ok,
              %SentNotification{
                notification_type: :sms,
                driver_id: ^driver_id,
                match_id: ^match_id,
                phone_number: "+15134021234",
                external_id: "SMa966f710be1843f3a8f9287b3d913e59",
                device_id: nil,
                shipper_id: nil,
                schedule_id: nil,
                delivery_batch_id: nil,
                notification_batch_id: nil
              }} = Notifications.send_notification(:sms, driver, match, %{body: "test message"})
    end

    test "sends delivery batch notification" do
      driver = insert(:driver) |> set_driver_default_device()

      %{id: delivery_batch_id} = delivery_batch = insert(:delivery_batch)

      assert {:ok,
              %SentNotification{
                notification_type: :push,
                match_id: nil,
                schedule_id: nil,
                delivery_batch_id: ^delivery_batch_id
              }} =
               Notifications.send_notification(:push, driver, delivery_batch, %{
                 title: "test title",
                 message: "test message"
               })
    end

    test "sends schedule notification" do
      driver = insert(:driver) |> set_driver_default_device()

      %{id: schedule_id} = schedule = insert(:schedule)

      assert {:ok,
              %SentNotification{
                notification_type: :push,
                match_id: nil,
                schedule_id: ^schedule_id,
                delivery_batch_id: nil
              }} =
               Notifications.send_notification(:push, driver, schedule, %{
                 title: "test title",
                 message: "test message"
               })
    end

    test "returns error when sms fails to send" do
      shipper = insert(:shipper, phone: "000")
      match = insert(:match)

      assert {:error,
              %{"message" => "The 'To' number 000 is not a valid phone number.", "status" => 400},
              _meta} =
               Notifications.send_notification(:sms, shipper, match, %{body: "test message"})
    end

    test "returns error when push fails to send" do
      shipper = insert(:shipper, one_signal_id: "bad")
      match = insert(:match)

      assert {:error, %{"errors" => _}, _meta} =
               Notifications.send_notification(:push, shipper, match, %{})
    end

    test "returns error with invalid attrs" do
      shipper = insert(:shipper)
      match = build(:match)

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  is_test:
                    {_,
                     [
                       validation: :one_of_present,
                       among: [
                         :is_test,
                         :notification,
                         :match_id,
                         :schedule_id,
                         :delivery_batch_id,
                         :admin_user_id
                       ]
                     ]}
                ]
              },
              _meta} =
               Notifications.send_notification(:push, shipper, match, %{
                 title: "test title",
                 message: "test message"
               })
    end

    test "sends notification with attrs" do
      %{id: driver_id} = driver = insert(:driver) |> set_driver_default_device()

      %{id: match_id} = match = insert(:match)

      assert {:ok,
              %{
                notification_type: :push,
                driver_id: ^driver_id,
                match_id: ^match_id
              }} =
               %{}
               |> Notifications.send_notification(:push, driver, match, %{
                 title: "test title",
                 message: "test message"
               })
    end

    test "sends notification with multi" do
      %{id: driver_id} = driver = insert(:driver) |> set_driver_default_device()

      %{id: match_id} = match = insert(:match)

      key = {:notification, "#{match_id}_#{driver_id}"}

      assert {:ok,
              %{
                ^key => %SentNotification{
                  notification_type: :push,
                  driver_id: ^driver_id,
                  match_id: ^match_id
                }
              }} =
               Multi.new()
               |> Notifications.send_notification(:push, driver, match, %{
                 title: "test title",
                 message: "test message"
               })
               |> Repo.transaction()
    end

    test "returns multi with no errors when sms fails to send" do
      shipper = insert(:shipper, phone: "000")
      match = insert(:match)

      assert {:ok, res} =
               Multi.new()
               |> Notifications.send_notification(:sms, shipper, match, %{body: "test message"})
               |> Repo.transaction()

      assert res == %{}
    end

    test "returns multi with no errors when push fails to send" do
      driver = insert(:driver_with_wallet)
      device = insert(:device, driver_id: driver.id, player_id: "bad")
      driver = set_driver_default_device(driver, device)

      match = insert(:match)

      assert {:ok, res} =
               Multi.new()
               |> Notifications.send_notification(:push, driver, match, %{
                 title: "test title",
                 message: "test message"
               })
               |> Repo.transaction()

      assert res == %{}
    end
  end
end
