defmodule FraytElixir.Shipment.UnacceptedMatchNotifier do
  use GenServer

  alias FraytElixir.Shipment
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.Company
  alias FraytElixir.Matches
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Notifications.Slack
  alias FraytElixir.MatchSupervisor

  def new(
        %Match{} = match,
        interval \\ 100,
        max \\ 1000
      ) do
    GenServer.start_link(
      __MODULE__,
      %{match: match, interval: interval, max: max},
      name: name_for(match)
    )
  end

  def name_for(%Match{id: match_id}), do: {:global, "unaccepted_match_notifier:#{match_id}"}

  def init(%{
        match: %Match{} = match,
        interval: interval,
        max: max
      }) do
    {initial_interval, elapsed} = get_initial_config(match, interval)

    Process.send_after(
      self(),
      :send_notification,
      initial_interval
    )

    {:ok,
     %{
       match: match,
       interval: interval,
       max: max,
       elapsed: elapsed
     }}
  end

  def handle_info(:send_notification, %{
        match: match,
        interval: interval,
        max: max,
        elapsed: elapsed
      })
      when elapsed >= max do
    {message, level} = message(match, elapsed, max)

    cond do
      match.state == :assigning_driver and deliver_pro?(match) ->
        Matches.handle_unaccepted_preferred_driver_match(match)

      match.state == :assigning_driver and auto_cancel?(match) ->
        Shipment.admin_cancel_match(match, "Canceled automatically since it " <> message)

      true ->
        Slack.send_match_message(match, message <> " This is the final warning.", level)
    end

    {:stop, :normal,
     %{
       match: match,
       interval: interval,
       max: max,
       elapsed: elapsed
     }}
  end

  def handle_info(:send_notification, %{
        match: match,
        interval: interval,
        max: max,
        elapsed: elapsed
      }) do
    # IO.puts("Sending unaccepted match slack notifications for #{match.id}")
    Process.send_after(self(), :send_notification, interval)

    case Shipment.get_match(match.id) do
      %Match{} = match ->
        MatchSupervisor.start_match_driver_notifier(match)

        {message, level} = message(match, elapsed, max)
        Slack.send_match_message(match, message, level)

        #  TODO: REIMPLEMENT THIS FEATURE
        # {:ok, match} =
        #   with %Company{auto_incentivize_driver: true} <- Accounts.get_match_company(match) do
        #     # Pricing.increase_driver_cut(match)
        #   else
        #     _ -> {:ok, match}
        #   end

        {:noreply,
         %{
           match: match,
           interval: interval,
           max: max,
           elapsed: elapsed + interval
         }}

      _ ->
        Slack.send_match_message(
          match,
          "Unable to find this Match. Unaccepted notifier will be terminated.",
          :danger
        )

        {:stop, :normal,
         %{
           match: match,
           interval: interval,
           max: max,
           elapsed: elapsed
         }}
    end
  end

  # handle occasional spurious messages from hackney without crashing
  def handle_info({:ssl_closed, _}, state) do
    {:noreply, state}
  end

  def get_initial_config(%Match{pickup_at: pickup_at, scheduled: true}, interval)
      when not is_nil(pickup_at) do
    now = DateTime.utc_now()

    thirty_min_before_pickup =
      pickup_at
      |> DateTime.add(-30 * 60, :second)

    elapsed = DateTime.diff(now, thirty_min_before_pickup, :millisecond)

    (DateTime.diff(pickup_at, now, :millisecond) - 30 * 60 * 1_000)
    |> case do
      time when time < 0 ->
        {closest_interval_in_milliseconds(time, interval), elapsed}

      time ->
        {time, elapsed |> max(0)}
    end
  end

  def get_initial_config(%Match{scheduled: false} = match, interval) do
    case Shipment.match_transitioned_at(match, :assigning_driver) do
      %NaiveDateTime{} = activated_at ->
        elapsed = NaiveDateTime.diff(NaiveDateTime.utc_now(), activated_at, :millisecond)

        interval =
          if elapsed > 0,
            do: closest_interval_in_milliseconds(elapsed, interval),
            else: interval

        {interval, elapsed}

      _ ->
        {interval, interval}
    end
  end

  def get_initial_config(_, interval), do: {interval, interval}

  defp closest_interval_in_milliseconds(millis, interval) do
    millis = millis |> abs() |> rem(interval)
    interval - millis
  end

  defp milliseconds_to_minutes(millis), do: :erlang.float_to_binary(millis / 60_000, decimals: 0)

  defp message(match, elapsed, max) when elapsed >= max,
    do: {message(match, elapsed), :danger}

  defp message(match, elapsed, _max), do: {message(match, elapsed), :warning}

  defp message(%Match{pickup_at: pickup_at, scheduled: true}, _elapsed)
       when not is_nil(pickup_at),
       do:
         pickup_at
         |> DateTime.diff(DateTime.utc_now(), :millisecond)
         |> scheduled_time_message()
         |> Kernel.<>(" and no driver has accepted.")

  defp message(_match, elapsed),
    do: "has been up for #{milliseconds_to_minutes(elapsed)} minutes without a driver accepting."

  defp scheduled_time_message(time) when time < 0,
    do: "needed picked up #{milliseconds_to_minutes(abs(time))} minutes ago"

  defp scheduled_time_message(time),
    do: "needs picked up in #{milliseconds_to_minutes(time)} minutes"

  defp auto_cancel?(match) do
    case Accounts.get_match_company(match) do
      %Company{auto_cancel: true} -> true
      _ -> false
    end
  end

  defp deliver_pro?(%{platform: :deliver_pro} = _match) do
    true
  end

  defp deliver_pro?(_match) do
    false
  end
end
