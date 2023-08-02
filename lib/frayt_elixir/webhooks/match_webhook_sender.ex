defmodule FraytElixir.Webhooks.MatchWebhookSender do
  use GenServer
  alias Phoenix.PubSub
  alias FraytElixir.Repo
  import Ecto.Query

  alias FraytElixir.Shipment

  alias FraytElixir.Shipment.{
    Match,
    MatchStop
  }

  alias FraytElixir.Accounts.{Company, Location, Shipper}
  alias FraytElixirWeb.Endpoint
  alias FraytElixir.Webhooks
  alias FraytElixir.Webhooks.WebhookSupervisor

  @active_states Shipment.MatchState.active_range() ++ [:scheduled]
  @canceled_states Shipment.MatchState.canceled_range()

  def init_webhook_senders do
    all_pending_webhooks = Webhooks.fetch_unprocessed(:match)

    match_ids = Enum.map(all_pending_webhooks, & &1.record_id)

    matches =
      from(m in Match,
        where: m.state in ^@active_states or m.id in ^match_ids
      )
      |> Repo.all()

    Enum.map(matches, fn match ->
      pending_webhooks = Enum.filter(all_pending_webhooks, &(&1.record_id == match.id))

      WebhookSupervisor.start_match_webhook_sender(match, pending_webhooks)
    end)
  end

  def start_link(http_post, match, pending_webhooks) do
    GenServer.start_link(__MODULE__, [http_post, match, pending_webhooks],
      name: name_for(match.id)
    )
  end

  def name_for(match_id), do: {:global, "match_webhook_sender:#{match_id}"}

  @impl true
  def init([http_post, match, pending_webhooks]) do
    :ok = PubSub.subscribe(FraytElixir.PubSub, "match_state_transitions:#{match.id}")
    location_updates? = update_driver_location_subscription(match)

    state = %{
      http_post: http_post,
      match: match,
      pending_webhooks: pending_webhooks,
      location_updates?: location_updates?
    }

    if is_nil(pending_webhooks) or Enum.empty?(pending_webhooks) do
      {:ok, state}
    else
      {:ok, state, {:continue, :process_pending_webhooks}}
    end
  end

  @impl true
  def handle_continue(:process_pending_webhooks, state) do
    Enum.each(state.pending_webhooks, &Webhooks.process_webhook(&1, state.http_post))

    state = %{state | pending_webhooks: []}
    maybe_shutdown(state)
  end

  @impl true
  def handle_info({%MatchStop{match_id: match_id}, transition}, %{http_post: http_post} = state) do
    match = Shipment.get_match(match_id)
    init_webhook(match, http_post, transition)

    {:noreply, state}
  end

  def handle_info({%Match{} = match, transition}, state) do
    init_webhook(match, state.http_post, transition)

    location_updates? =
      update_driver_location_subscription(match, state.location_updates?, state.match.driver_id)

    state = %{state | match: match, location_updates?: location_updates?}

    maybe_shutdown(state, transition && transition.from)
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "driver_location",
          payload: _,
          topic: "driver_locations:" <> driver_id
        },
        state
      ) do
    case Repo.get(Match, state.match.id) do
      %Match{driver_id: ^driver_id, state: match_state} = match
      when match_state in @active_states ->
        init_webhook(match, state.http_post, nil)
        maybe_shutdown(state)

      _ ->
        :ok = Endpoint.unsubscribe("driver_locations:#{driver_id}")
        maybe_shutdown(state)
    end
  end

  defp update_driver_location_subscription(
         match,
         subscribed? \\ false,
         old_driver_id \\ nil
       ) do
    cond do
      not is_nil(match.driver_id) and match.state in @active_states ->
        :ok = Endpoint.subscribe("driver_locations:#{match.driver_id}")
        true

      subscribed? and match.driver_id != old_driver_id ->
        :ok = Endpoint.unsubscribe("driver_locations:#{old_driver_id}")
        :ok = Endpoint.subscribe("driver_locations:#{match.driver_id}")
        true

      subscribed? ->
        :ok = Endpoint.unsubscribe("driver_locations:#{old_driver_id}")
        false

      true ->
        subscribed?
    end
  end

  defp init_webhook(match, http_post, transition) do
    case preload_record(match) do
      %Match{
        driver_id: _driver_id,
        shipper: %Shipper{location: %Location{company: %Company{} = company}}
      } = match ->
        Webhooks.init_webhook_request(
          company,
          match,
          "match",
          http_post,
          transition
        )

      _ ->
        nil
    end
  end

  defp preload_record(%Match{} = match),
    do:
      match
      |> Repo.preload([
        :sender,
        :contract,
        :eta,
        shipper: [location: :company],
        driver: [:user, :vehicles, :current_location],
        match_stops: [:items, :destination_address, :recipient, :eta]
      ])

  defp maybe_shutdown(state, from_state \\ nil) do
    cond do
      state.match.state in (@active_states ++ [:pending]) ->
        {:noreply, state}

      state.match.state in @canceled_states and from_state == :picked_up ->
        {:noreply, state}

      true ->
        :ok = PubSub.unsubscribe(FraytElixir.PubSub, "match_state_transitions:#{state.match.id}")

        {:stop, :normal, state}
    end
  end
end
