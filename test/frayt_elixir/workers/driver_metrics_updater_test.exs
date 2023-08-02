defmodule FraytElixir.Workers.DriverMetricsUpdaterTest do
  use FraytElixir.DataCase

  import FraytElixir.Factory

  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Workers.DriverMetricsUpdater

  test "updates driver metrics" do
    FakeSlack.clear_messages()

    d = insert(:driver, metrics: nil)
    insert_list(5, :completed_match, driver: d, driver_total_pay: 1000)
    insert_list(10, :charged_match, driver: d, driver_total_pay: 1000)
    insert_list(3, :charged_match, rating: 4, driver: d, driver_total_pay: 1000)
    insert_list(3, :hidden_match, type: "driver_cancellation", driver: d)
    insert(:charged_match, rating: 1, driver: d, driver_total_pay: 1000)
    DriverMetricsUpdater.perform("")

    assert [
             {"#test-appsignal", "Finished updating 4 driver metrics after 0 seconds"},
             {"#test-appsignal", "Starting metrics update for all drivers"}
           ] == FakeSlack.get_messages("#test-appsignal")
  end
end
