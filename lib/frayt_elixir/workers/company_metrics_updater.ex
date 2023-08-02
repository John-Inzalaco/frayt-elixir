defmodule FraytElixir.Workers.CompanyMetricsUpdater do
  use Oban.Worker, queue: :metrics

  alias FraytElixir.Notifications.Slack
  alias FraytElixir.Accounts

  @impl Oban.Worker
  def perform(_) do
    started_at = DateTime.utc_now()

    Slack.send_message(
      :appsignal,
      "Starting company aggregate update"
    )

    case Accounts.update_company_metrics() do
      {:error, msg} ->
        Slack.send_message(:appsignal, "Error calculating company metrics: #{msg}")
        {:error, msg}

      {entries, nil} ->
        difference = DateTime.diff(DateTime.utc_now(), started_at, :second)

        Slack.send_message(
          :appsignal,
          "Finished updating #{entries} company metrics after #{difference} seconds"
        )

        :ok
    end
  end
end
