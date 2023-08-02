defmodule FraytElixir.Shipment.NotPickedUpNotifier do
  use GenServer

  alias FraytElixir.Shipment.Match
  alias FraytElixir.Notifications.Slack
  alias FraytElixirWeb.DisplayFunctions

  def new(
        match,
        unscheduled_delay \\ 0,
        interval \\ 100,
        max \\ 1000
      )

  def new(
        match,
        unscheduled_delay,
        interval,
        max
      ) do
    GenServer.start_link(
      __MODULE__,
      %{
        match: match,
        unscheduled_delay: unscheduled_delay,
        interval: interval,
        max: max
      },
      name: name_for(match)
    )
  end

  def name_for(%Match{id: match_id}), do: {:global, "not_picked_up_notifier:#{match_id}"}

  def init(%{
        match: %Match{} = match,
        unscheduled_delay: unscheduled_delay,
        interval: interval,
        max: max
      }) do
    initial_interval = initial_interval(match, unscheduled_delay, interval)
    elapsed_offset = initial_interval - interval

    Process.send_after(
      self(),
      :send_notification,
      initial_interval
    )

    {:ok,
     %{
       match: match,
       unscheduled_delay: unscheduled_delay,
       interval: interval,
       max: max,
       elapsed: interval,
       elapsed_offset: elapsed_offset
     }}
  end

  def initial_interval(%Match{scheduled: true, pickup_at: pickup_at}, _, interval)
      when not is_nil(pickup_at) do
    # This will start sending notifications 10 minutes after scheduled pickup
    pickup_at
    |> DateTime.add(interval, :millisecond)
    |> DateTime.diff(DateTime.utc_now(), :millisecond)
    |> Kernel.max(0)
  end

  def initial_interval(_, unscheduled_delay, _interval) do
    # This will start sending notifications #{unscheduled_delay} milliseconds after current time
    DateTime.utc_now()
    |> DateTime.add(unscheduled_delay, :millisecond)
    |> DateTime.diff(DateTime.utc_now(), :millisecond)
    |> Kernel.max(0)
  end

  def handle_info(:send_notification, %{
        match: match,
        unscheduled_delay: unscheduled_delay,
        interval: interval,
        max: max,
        elapsed: elapsed,
        elapsed_offset: elapsed_offset
      })
      when elapsed >= max do
    {:stop, :normal,
     %{
       match: match,
       unscheduled_delay: unscheduled_delay,
       interval: interval,
       max: max,
       elapsed: elapsed,
       elapsed_offset: elapsed_offset
     }}
  end

  def handle_info(:send_notification, %{
        match: match,
        unscheduled_delay: unscheduled_delay,
        interval: interval,
        max: max,
        elapsed: elapsed,
        elapsed_offset: elapsed_offset
      }) do
    # IO.puts("Sending not enroute dropoff match slack notifications for #{match.id}")
    Process.send_after(self(), :send_notification, interval)
    {message, level} = message(match, interval, max, elapsed, elapsed_offset)
    Slack.send_match_message(match, message, level)

    {:noreply,
     %{
       match: match,
       unscheduled_delay: unscheduled_delay,
       interval: interval,
       max: max,
       elapsed: elapsed + interval,
       elapsed_offset: elapsed_offset
     }}
  end

  # handle occasional spurious messages from hackney without crashing
  def handle_info({:ssl_closed, _}, state) do
    {:noreply, state}
  end

  defp milliseconds_to_minutes(millis), do: :erlang.float_to_binary(millis / 60_000, decimals: 0)

  defp message(match, interval, max, elapsed, elapsed_offset) when elapsed + interval >= max do
    {message, _} = message(match, elapsed, elapsed_offset)
    {"#{message} This is the final warning.", :danger}
  end

  defp message(match, _interval, _max, elapsed, elapsed_offset),
    do: message(match, elapsed, elapsed_offset)

  defp message(
         %Match{
           scheduled: true,
           pickup_at: pickup_at,
           driver: driver,
           origin_address: origin_address
         },
         elapsed,
         _elapsed_offset
       ),
       do: {
         "was accepted by Driver #{driver.first_name} #{driver.last_name} and has not picked up #{milliseconds_to_minutes(elapsed)} minutes after scheduled pickup (#{DisplayFunctions.display_date_time_long(pickup_at, origin_address)})",
         :danger
       }

  defp message(%Match{scheduled: false, driver: driver}, elapsed, elapsed_offset),
    do: {
      "was accepted by Driver #{driver.first_name} #{driver.last_name} #{milliseconds_to_minutes(elapsed + elapsed_offset)} minutes ago and has not picked up.",
      :warning
    }
end
