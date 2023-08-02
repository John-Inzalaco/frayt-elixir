defmodule FraytElixir.Shipment.IdleDriverNotifier do
  use GenServer

  alias Phoenix.PubSub
  alias Calendar
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Notifications.Slack
  alias FraytElixir.Workers.IdleDriverWorker

  require Logger

  @config Application.compile_env(:frayt_elixir, __MODULE__, [])

  @scheduled_alert_interval Keyword.fetch!(@config, :scheduled_alert_interval)
  @short_notice_time Keyword.fetch!(@config, :short_notice_time)
  @warning_interval Keyword.fetch!(@config, :warning_interval)
  @short_notice_interval Keyword.fetch!(@config, :short_notice_interval)
  @cancel_interval Keyword.fetch!(@config, :cancel_interval)

  # this function is here just for the tests to pass
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ok = PubSub.subscribe(FraytElixir.PubSub, "match_state_transitions")

    {:ok, %{subscribed_matches: %{}}}
  end

  # Testing Purposes only
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(
        {:put_match, %Match{id: match_id, driver_id: driver_id}},
        _from,
        %{subscribed_matches: subscribed_matches} = state
      ) do
    {:reply, :ok,
     %{
       state
       | subscribed_matches: subscribed_matches |> add_subscribed_match(driver_id, match_id)
     }}
  end

  def handle_call({:set_stop_flag, stop_flag}, _from, state) do
    state =
      state
      |> Map.put(:stop_flag, stop_flag)

    {:reply, state, state}
  end

  @impl true
  def handle_info(
        {%Match{state: :accepted, driver_id: driver_id, id: match_id, scheduled: false} = match,
         _transition},
        %{subscribed_matches: subscribed_matches} = state
      ) do
    Process.send_after(self(), {:warn_driver, match}, @warning_interval)

    {:noreply,
     %{
       state
       | subscribed_matches: subscribed_matches |> add_subscribed_match(driver_id, match_id)
     }}
  end

  def handle_info(
        {%Match{
           state: :accepted,
           driver_id: driver_id,
           id: match_id,
           scheduled: true,
           pickup_at: pickup_at
         } = match, _transition},
        %{subscribed_matches: subscribed_matches} = state
      ) do
    scheduled_alert_interval(pickup_at)

    short_notice = short_notice?(pickup_at)

    case short_notice do
      true ->
        Process.send_after(self(), {:warn_driver, match}, @short_notice_interval)

      _ ->
        Process.send_after(
          self(),
          {:scheduled_pickup_alert, match},
          scheduled_alert_interval(pickup_at)
        )
    end

    {:noreply,
     %{
       state
       | subscribed_matches:
           subscribed_matches |> add_subscribed_match(driver_id, match_id, short_notice)
     }}
  end

  def handle_info(
        {%Match{state: match_state, driver_id: driver_id, id: match_id} = _match, _transition},
        %{subscribed_matches: subscribed_matches} = state
      )
      when match_state in [
             :en_route_to_pickup,
             :completed,
             :admin_canceled,
             :driver_canceled,
             :canceled
           ] do
    {:noreply,
     %{
       state
       | subscribed_matches: subscribed_matches |> remove_subscribed_match(driver_id, match_id)
     }}
  end

  def handle_info(
        {:scheduled_pickup_alert,
         %Match{driver: driver, id: match_id, driver_id: driver_id} = match},
        %{subscribed_matches: subscribed_matches} = state
      ) do
    with {:ok, _} <- get_subscribed(subscribed_matches, driver_id, match_id),
         {:ok, _} <- check_pickup_time(match) do
      Slack.send_match_message(
        match,
        "Driver has accepted a Match that needs to be picked up in 30 minutes",
        :alert
      )

      %{driver_id: driver.id, match_id: match.id, type: "scheduled_pickup_alert"}
      |> IdleDriverWorker.new()
      |> Oban.insert()

      Process.send_after(self(), {:warn_driver, match}, @warning_interval)
    else
      {:change, %Match{pickup_at: updated_pickup} = updated_match} ->
        Process.send_after(
          self(),
          {:scheduled_pickup_alert, updated_match},
          scheduled_alert_interval(updated_pickup)
        )

      _ ->
        nil
    end

    {:noreply, state}
  end

  def handle_info(
        {:warn_driver, %Match{id: match_id, driver_id: driver_id}},
        %{subscribed_matches: subscribed_matches, stop_flag: :warn_driver} = state
      ),
      do: {
        :noreply,
        %{
          state
          | subscribed_matches: subscribed_matches |> remove_subscribed_match(driver_id, match_id)
        }
      }

  def handle_info(
        {:warn_driver, %Match{id: match_id, driver: driver, driver_id: driver_id} = match},
        %{subscribed_matches: subscribed_matches} = state
      ) do
    with {:ok, {_, short_notice?}} <- get_subscribed(subscribed_matches, driver_id, match_id) do
      Slack.send_match_message(
        match,
        "Driver has been warned of removal if not en route shortly.",
        :alert,
        channel: :high_priority_dispatch
      )

      %{driver_id: driver.id, match_id: match.id, type: "idle_driver_warning"}
      |> IdleDriverWorker.new()
      |> Oban.insert()

      if not short_notice? do
        Process.send_after(self(), {:cancel_match, match}, @cancel_interval)
      end
    end

    {:noreply, state}
  end

  def handle_info(
        {:cancel_match, %Match{id: match_id, driver_id: driver_id}},
        %{subscribed_matches: subscribed_matches, stop_flag: :cancel_driver} = state
      ),
      do: {
        :noreply,
        %{
          state
          | subscribed_matches: subscribed_matches |> remove_subscribed_match(driver_id, match_id)
        }
      }

  def handle_info(
        {:cancel_match, %Match{driver: _driver, driver_id: driver_id, id: match_id} = _match},
        %{subscribed_matches: subscribed_matches} = state
      ) do
    case get_subscribed(subscribed_matches, driver_id, match_id) do
      {:ok, _} ->
        state = %{
          state
          | subscribed_matches: subscribed_matches |> remove_subscribed_match(driver_id, match_id)
        }

        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_, state), do: {:noreply, state}

  defp get_subscribed(subscribed_matches, driver_id, match_id) do
    result =
      subscribed_matches
      |> Map.get(driver_id, [])
      |> Enum.find(fn {id, _short_notice} -> id == match_id end)

    case result do
      nil -> {:error, nil}
      _ -> {:ok, result}
    end
  end

  def short_notice?(pickup_at) do
    short_notice_end_time = DateTime.utc_now() |> DateTime.add(@short_notice_time, :millisecond)

    DateTime.diff(short_notice_end_time, pickup_at) > 0
  end

  defp add_subscribed_match(subscribed_matches, driver_id, match_id, short_notice \\ false)

  defp add_subscribed_match(subscribed_matches, driver_id, match_id, short_notice) do
    matches_for_driver = subscribed_matches |> Map.get(driver_id, [])

    Map.put(subscribed_matches, driver_id, [
      {match_id, short_notice} | matches_for_driver
    ])
  end

  defp remove_subscribed_match(subscribed_matches, driver_id, match_id) do
    matches_for_driver =
      subscribed_matches
      |> Map.get(driver_id, [])
      |> Enum.filter(fn {id, _} -> id != match_id end)

    Map.put(subscribed_matches, driver_id, matches_for_driver)
    |> purge_subscriptions()
  end

  defp purge_subscriptions(subscribed_matches) do
    purgable =
      subscribed_matches
      |> Map.to_list()
      |> Enum.filter(fn {_k, v} -> [] != v end)
      |> Enum.map(fn {k, _v} -> k end)

    subscribed_matches
    |> Map.take(purgable)
  end

  defp check_pickup_time(%Match{pickup_at: pickup_at, id: match_id}) do
    %Match{pickup_at: updated_pickup} = updated_match = Shipment.get_match!(match_id)

    case DateTime.diff(pickup_at, updated_pickup) do
      0 ->
        {:ok, updated_pickup}

      _ ->
        {:change, updated_match}
    end
  end

  defp scheduled_alert_interval(pickup_at) do
    pickup_at
    |> DateTime.add(-@scheduled_alert_interval, :millisecond)
    |> DateTime.diff(DateTime.utc_now(), :millisecond)
    |> Kernel.max(0)
  end
end
