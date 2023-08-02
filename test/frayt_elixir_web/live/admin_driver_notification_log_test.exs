defmodule FraytElixirWeb.AdminDriverNotificationLogTest do
  use FraytElixir.DataCase
  alias FraytElixir.Notifications
  alias FraytElixirWeb.AdminDriverNotificationLog

  describe "driver notification log" do
    test "returns list of notifications from matches, schedules, batches, and admins" do
      driver = insert(:driver)
      driver = set_driver_default_device(driver)

      %{id: match_id} = match = insert(:match)

      Notifications.send_notification(:push, driver, match, %{
        title: "test title",
        message: "test message"
      })

      %{id: schedule_id} = schedule = insert(:schedule)

      Notifications.send_notification(:push, driver, schedule, %{
        title: "test title",
        message: "test message"
      })

      %{id: delivery_batch_id} = delivery_batch = insert(:delivery_batch)

      Notifications.send_notification(:push, driver, delivery_batch, %{
        title: "test title",
        message: "test message"
      })

      %{id: admin_user_id} = admin_user = insert(:admin_user)

      Notifications.send_notification(:push, driver, admin_user, %{
        title: "test title",
        message: "test message"
      })

      notifications = AdminDriverNotificationLog.get_driver_notifications(driver)

      assert Enum.find(notifications, &(&1.match_id == match_id))
      assert Enum.find(notifications, &(&1.schedule_id == schedule_id))
      assert Enum.find(notifications, &(&1.delivery_batch_id == delivery_batch_id))
      assert Enum.find(notifications, &(&1.admin_user_id == admin_user_id))
    end
  end
end
