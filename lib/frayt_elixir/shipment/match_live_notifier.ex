defmodule FraytElixir.Shipment.MatchLiveNotifier do
  use GenServer
  alias Phoenix.PubSub
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Notifications.Slack

  # this function is here just for the tests to pass
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ok = PubSub.subscribe(FraytElixir.PubSub, "match_state_transitions")

    {:ok, []}
  end

  @impl true
  def handle_info(
        {%Match{state: :assigning_driver} = match, _transition},
        state
      ) do
    Slack.send_match_message(match, "has become live.")

    {:noreply, state}
  end

  def handle_info(
        {%Match{state: :scheduled} = match, _transition},
        state
      ) do
    Slack.send_match_message(match, "has been scheduled")

    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
