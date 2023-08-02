defmodule FraytElixir.Workers.IdleDriverWorker do
  use Oban.Worker

  alias FraytElixir.Notifications.DriverNotification
  alias FraytElixir.Drivers
  alias FraytElixir.Shipment

  @impl Oban.Worker
  def perform(%{
        args: %{
          "driver_id" => driver_id,
          "match_id" => match_id,
          "type" => "scheduled_pickup_alert"
        }
      }) do
    driver = Drivers.get_driver(driver_id)
    match = Shipment.get_match(match_id)
    DriverNotification.send_scheduled_pickup_alert(driver, match)
    :ok
  end

  def perform(%{
        args: %{"driver_id" => driver_id, "match_id" => match_id, "type" => "idle_driver_warning"}
      }) do
    driver = Drivers.get_driver(driver_id)
    match = Shipment.get_match(match_id)

    DriverNotification.send_idle_driver_warning(driver, match)

    :ok
  end

  def perform(%{
        args: %{
          "driver_id" => driver_id,
          "match_id" => match_id,
          "type" => "idle_driver_cancellation"
        }
      }) do
    driver = Drivers.get_driver(driver_id)
    match = Shipment.get_match(match_id)

    DriverNotification.send_idle_driver_cancellation(driver, match)

    {:ok, _updated_match} =
      Drivers.cancel_match(match, "Driver has been removed due to inactivity.")

    # TODO: REIMPLEMENT THIS FEATURE
    # Pricing.increase_driver_cut(updated_match)
    :ok
  end
end
