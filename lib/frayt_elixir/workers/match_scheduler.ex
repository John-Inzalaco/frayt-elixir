defmodule FraytElixir.Workers.MatchScheduler do
  use Oban.Worker

  alias FraytElixir.Shipment.MatchWorkflow

  @impl Oban.Worker
  def perform(_) do
    MatchWorkflow.activate_upcoming_scheduled_matches()
    :ok
  end
end
