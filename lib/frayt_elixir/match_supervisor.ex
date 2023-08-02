defmodule FraytElixir.MatchSupervisor do
  use DynamicSupervisor

  @config Application.compile_env(:frayt_elixir, __MODULE__, [])

  @slack_notification_interval Keyword.fetch!(@config, :slack_notification_interval)
  @slack_max_notification_interval Keyword.fetch!(@config, :slack_max_notification_interval)
  @unscheduled_delay Keyword.fetch!(@config, :unscheduled_delay)
  @driver_distance_increment Keyword.fetch!(@config, :driver_distance_increment)
  @final_distance_increment Keyword.fetch!(@config, :final_distance_increment)
  @driver_notification_interval Keyword.fetch!(@config, :driver_notification_interval)
  @init_unaccepted_match_notifiers_delay Keyword.fetch!(
                                           @config,
                                           :init_unaccepted_match_notifiers_delay
                                         )

  import Ecto.Query, warn: false
  alias FraytElixir.Drivers.MatchDriverNotifier
  alias FraytElixir.Repo

  alias FraytElixir.Shipment.{
    Match,
    UnacceptedMatchNotifier,
    NotEnrouteToDropoffNotifier,
    NotPickedUpNotifier
  }

  alias FraytElixir.CustomContracts

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.Company

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Task.start_link(fn ->
      :timer.sleep(@init_unaccepted_match_notifiers_delay)

      from(m in Match,
        where: m.state == "assigning_driver",
        preload: [:state_transitions, :contract]
      )
      |> Repo.all()
      |> Enum.each(&start_unaccepted_match_notifier/1)
    end)

    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_match_driver_notifier(%Match{} = match) do
    spec = %{
      id: MatchDriverNotifier,
      start:
        {MatchDriverNotifier, :new,
         [
           %{
             match: match,
             interval: @driver_notification_interval,
             distance_increment: @driver_distance_increment,
             final_distance_increment: @final_distance_increment
           }
         ]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_unaccepted_match_notifier(%Match{} = match) do
    max_notification_interval = get_max_notification_interval(match)

    spec = %{
      id: UnacceptedMatchNotifier,
      start:
        {UnacceptedMatchNotifier, :new,
         [
           match,
           @slack_notification_interval,
           max_notification_interval
         ]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_not_enroute_to_dropoff_match_notifier(%Match{} = match) do
    spec = %{
      id: NotEnrouteToDropoffNotifier,
      start:
        {NotEnrouteToDropoffNotifier, :new,
         [
           match,
           @slack_notification_interval,
           @slack_max_notification_interval
         ]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def start_not_picked_up_match_notifier(%Match{} = match) do
    spec = %{
      id: NotPickedUpNotifier,
      start:
        {NotPickedUpNotifier, :new,
         [
           match,
           @unscheduled_delay,
           @slack_notification_interval,
           @slack_max_notification_interval
         ]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def restart_unaccepted_match_notifier(match) do
    stop_unaccepted_match_notifier(match)
    start_unaccepted_match_notifier(match)
  end

  def start_assigning_drivers(%Match{} = match) do
    start_match_driver_notifier(match)
    start_unaccepted_match_notifier(match)
  end

  def start_accepted(%Match{} = match) do
    start_not_picked_up_match_notifier(match)
  end

  def stop_assigning_drivers(%Match{} = match) do
    stop_child(MatchDriverNotifier.name_for(match))
    stop_unaccepted_match_notifier(match)
  end

  def stop_not_enroute_to_dropoff_match_notifier(%Match{} = match) do
    stop_child(NotEnrouteToDropoffNotifier.name_for(match))
  end

  def stop_not_picked_up_match_notifier(%Match{} = match) do
    stop_child(NotPickedUpNotifier.name_for(match))
  end

  def stop_unaccepted_match_notifier(match) do
    stop_child(UnacceptedMatchNotifier.name_for(match))
  end

  defp get_max_notification_interval(nil),
    do: @slack_max_notification_interval

  defp get_max_notification_interval(%Company{auto_cancel: true, auto_cancel_time: time})
       when not is_nil(time),
       do: time

  defp get_max_notification_interval(%Company{}),
    do: @slack_max_notification_interval

  defp get_max_notification_interval(%Match{contract: nil} = match),
    do: Accounts.get_match_company(match) |> get_max_notification_interval()

  defp get_max_notification_interval(%Match{} = match) do
    case CustomContracts.get_auto_cancel_time(match) do
      {:ok, time} -> time
      _ -> @slack_max_notification_interval
    end
  end

  defp stop_child(child) do
    case GenServer.whereis(child) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end
