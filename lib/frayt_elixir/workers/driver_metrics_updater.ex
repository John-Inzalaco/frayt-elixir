defmodule FraytElixir.Workers.DriverMetricsUpdater do
  use Oban.Worker, queue: :metrics

  alias FraytElixir.Drivers
  alias FraytElixir.Notifications.Slack

  @impl Oban.Worker
  def perform(_) do
    started_at = DateTime.utc_now()

    Slack.send_message(
      :appsignal,
      "Starting metrics update for all drivers"
    )

    case Drivers.update_all_driver_metrics(timeout: 3 * 60_000) do
      {:error, msg} ->
        Slack.send_message(:appsignal, "Error calculating driver metrics: #{msg}")
        {:error, msg}

      {:ok, entries, nil} ->
        difference = DateTime.diff(DateTime.utc_now(), started_at, :second)

        Slack.send_message(
          :appsignal,
          "Finished updating #{entries} driver metrics after #{difference} seconds"
        )

        :ok
    end
  end
end
