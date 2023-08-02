defmodule FraytElixir.Shipment.NotEnrouteToDropoffNotifier do
  use GenServer

  alias FraytElixir.Shipment.Match
  alias FraytElixir.Notifications.Slack

  def new(
        match,
        interval \\ 100,
        max \\ 1000
      )

  def new(
        %Match{service_level: 1} = match,
        interval,
        max
      ) do
    GenServer.start_link(
      __MODULE__,
      %{match: match, interval: interval, max: max},
      name: name_for(match)
    )
  end

  def new(_, _, _), do: :nothing

  def name_for(%Match{id: match_id}), do: {:global, "not_enroute_to_dropoff_notifier:#{match_id}"}

  def init(%{
        match: %Match{} = match,
        interval: interval,
        max: max
      }) do
    Process.send_after(self(), :send_notification, initial_interval(match, interval))

    {:ok,
     %{
       match: match,
       interval: interval,
       max: max,
       elapsed: interval
     }}
  end

  def initial_interval(%Match{scheduled: true, dropoff_at: dropoff_at}, _)
      when not is_nil(dropoff_at) do
    dropoff_at
    |> DateTime.add(-1 * 1000 * 60 * 30, :millisecond)
    |> DateTime.diff(DateTime.utc_now(), :millisecond)
    |> Kernel.max(0)
  end

  def initial_interval(_, interval), do: interval

  def handle_info(:send_notification, %{
        match: match,
        interval: interval,
        max: max,
        elapsed: elapsed
      })
      when elapsed >= max do
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
    # IO.puts("Sending not enroute dropoff match slack notifications for #{match.id}")
    Process.send_after(self(), :send_notification, interval)

    {message, level} = message(match.driver, interval, max, elapsed)
    Slack.send_match_message(match, message, level)

    {:noreply,
     %{
       match: match,
       interval: interval,
       max: max,
       elapsed: elapsed + interval
     }}
  end

  # handle occasional spurious messages from hackney without crashing
  def handle_info({:ssl_closed, _}, state) do
    {:noreply, state}
  end

  defp milliseconds_to_minutes(millis), do: :erlang.float_to_binary(millis / 60_000, decimals: 0)

  defp message(driver, interval, max, elapsed) when elapsed + interval >= max,
    do: {message(driver, elapsed) <> "This is the final warning.", :alert}

  defp message(driver, _interval, _max, elapsed), do: {message(driver, elapsed), :alert}

  defp message(driver, elapsed),
    do:
      "was picked up by Driver #{driver.first_name} #{driver.last_name} #{milliseconds_to_minutes(elapsed)} minutes ago and is not yet En Route to dropoff."
end
