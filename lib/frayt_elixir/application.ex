defmodule FraytElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias FraytElixir.Webhooks.WebhookSupervisor

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    # List all child processes to be supervised
    children =
      [
        {Cluster.Supervisor, [topologies, [name: FraytElixir.ClusterSupervisor]]},
        # Start the Ecto repository
        FraytElixir.Repo,
        # Start the PubSub system
        {Phoenix.PubSub, [name: FraytElixir.PubSub, adapter: Phoenix.PubSub.PG2]},
        # Start the endpoint when the application starts
        FraytElixirWeb.Endpoint,
        # Starts a worker by calling: FraytElixir.Worker.start_link(arg)
        # {FraytElixir.Worker, arg},
        {Guardian.DB.Token.SweeperServer, []},
        {FraytElixir.Cache, []}
      ] ++ start_oban() ++ webhook_supervisor() ++ child_processes()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FraytElixir.Supervisor]

    with {:ok, _} = result <- Supervisor.start_link(children, opts) do
      unless Application.get_env(:frayt_elixir, :environment) == :test, do: singletons()
      result
    end
  end

  defp webhook_supervisor do
    if Application.get_env(:frayt_elixir, :environment) in [:prod, :dev] do
      [
        {WebhookSupervisor, &HTTPoison.post/4},
        {Task, &WebhookSupervisor.start_children/0}
      ]
    else
      []
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    FraytElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def singletons do
    Singleton.start_child(
      FraytElixir.Shipment.MatchLiveNotifier,
      [1],
      {:match_live_notifier, 1}
    )

    Singleton.start_child(
      FraytElixir.Shipment.IdleDriverNotifier,
      [1],
      {:idle_driver_notifier, 1}
    )

    Singleton.start_child(
      FraytElixir.Shipment.ETAPoller,
      [1],
      {:eta_poller, 1}
    )
  end

  def start_oban do
    case Application.fetch_env!(:frayt_elixir, Oban) do
      nil -> []
      config -> [{Oban, config}]
    end
  end

  def child_processes do
    Application.get_env(:frayt_elixir, :child_processes, [
      FraytElixir.MatchSupervisor,
      {Task.Supervisor, name: FraytElixir.Shipment.DeliveryBatchSupervisor}
    ])
  end
end
