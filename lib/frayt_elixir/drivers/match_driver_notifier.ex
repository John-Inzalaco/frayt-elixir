defmodule FraytElixir.Drivers.MatchDriverNotifier do
  use GenServer

  alias FraytElixir.Shipment.Match
  alias FraytElixir.Notifications.DriverNotification

  @initial_distance 5
  @max_distance 60

  def new(params) do
    %{
      match: %Match{} = match,
      interval: interval,
      distance_increment: distance_increment,
      final_distance_increment: final_distance_increment
    } = params

    GenServer.start_link(
      __MODULE__,
      %{
        match: match,
        interval: interval,
        distance_increment: distance_increment,
        final_distance_increment: final_distance_increment
      },
      name: name_for(match)
    )
  end

  def name_for(%Match{id: match_id}), do: {:global, "match_notify_drivers:#{match_id}"}

  def init(params) do
    %{
      match: %Match{} = match,
      interval: interval,
      distance_increment: distance_increment,
      final_distance_increment: final_distance_increment
    } = params

    Process.send_after(self(), :notify_drivers, 0)

    {:ok,
     %{
       match: match,
       distance: @initial_distance,
       count: 0,
       interval: interval,
       distance_increment: distance_increment,
       final_distance_increment: final_distance_increment
     }}
  end

  def handle_info(
        :notify_drivers,
        %{match: %{platform: :deliver_pro, preferred_driver_id: preferred_driver_id} = match} =
          state
      ) do
    if preferred_driver_id do
      {:ok, _} = DriverNotification.send_available_match_notification(match)
    end

    {:stop, :normal, state}
  end

  def handle_info(:notify_drivers, %{match: match, distance: distance} = state)
      when distance >= @max_distance do
    %{
      distance_increment: distance_increment
    } = state

    prev_distance = distance - distance_increment

    {:ok, _} =
      DriverNotification.send_available_match_notifications(
        match,
        @max_distance,
        prev_distance,
        false
      )

    {:stop, :normal, state}
  end

  def handle_info(:notify_drivers, params) do
    %{
      match: match,
      distance: distance,
      count: count,
      interval: interval,
      distance_increment: distance_increment,
      final_distance_increment: final_distance_increment
    } = params

    prev_distance = if distance < distance_increment, do: 0, else: distance - distance_increment

    {:ok, sent} =
      DriverNotification.send_available_match_notifications(match, distance, prev_distance, false)

    # When no one is notified within the distance range
    # then the range is immediately increased and
    # drivers within the next range are notified.
    next_interval = if Enum.empty?(sent), do: 0, else: interval

    next_distance =
      case distance + final_distance_increment do
        d when d >= @max_distance -> d
        _ -> distance + distance_increment
      end

    Process.send_after(self(), :notify_drivers, next_interval)

    {:noreply,
     %{
       match: match,
       distance: next_distance,
       count: count + Enum.count(sent),
       interval: interval,
       distance_increment: distance_increment,
       final_distance_increment: final_distance_increment
     }}
  end
end
