defmodule FraytElixir.Shipment.MatchWorkflow do
  alias FraytElixir.{Accounts, CustomContracts, Shipment, MatchSupervisor, Drivers, SLAs}

  alias FraytElixir.Shipment.{
    Match,
    MatchTags,
    MatchState,
    MatchStop,
    MatchStopState,
    MatchStopStateTransition,
    MatchStateTransition
  }

  alias FraytElixir.Matches

  alias FraytElixir.Accounts.Company

  alias FraytElixir.Notifications.MatchNotifications
  alias FraytElixir.Repo
  alias Phoenix.PubSub
  alias FraytElixir.Hubspot
  alias FraytElixir.Webhooks.WebhookSupervisor
  require Logger

  import Ecto.Query, warn: false
  import FraytElixir.Guards
  alias Ecto.Association.NotLoaded

  @all_states MatchState.all_indexes() |> Enum.sort(&(elem(&1, 1) < elem(&2, 1)))
  @all_stop_states MatchStopState.all_indexes() |> Enum.sort(&(elem(&1, 1) < elem(&2, 1)))

  @completed_stop_states MatchStopState.completed_range()

  @scheduled_match_threshold 24 * 3600
  @box_truck_scheduled_match_threshold 48 * 3600
  def activate_match(
        %Match{scheduled: true, pickup_at: pickup_at, vehicle_class: vehicle_class} = match
      )
      when not is_nil(pickup_at) do
    case DateTime.compare(pickup_at, future_scheduling_threshold(vehicle_class)) do
      :gt -> :scheduled
      _ -> :assigning_driver
    end
    |> state_transition(match)
  end

  def activate_match(%Match{} = match) do
    state_transition(match, :assigning_driver)
  end

  def recharge_match(%Match{state: :charged} = match) do
    state_transition(match, :completed)
  end

  def recharge_match(%Match{state: _} = match), do: {:ok, match}

  def pending(%MatchStop{state: state} = stop) when state in [:en_route, :arrived, :signed] do
    state_transition(stop, :pending, driver_location: stop.match.driver.current_location)
  end

  def unserved(match_stop, message), do: state_transition(match_stop, :unserved, notes: message)

  def accept_match(%Match{} = match),
    do: state_transition(match, :accepted, driver_location: match.driver.current_location)

  def en_route_to_pickup(%Match{state: :accepted} = match),
    do:
      state_transition(match, :en_route_to_pickup, driver_location: match.driver.current_location)

  def arrive_at_pickup(%Match{} = match, parking_spot \\ nil),
    do:
      state_transition(
        match,
        :arrived_at_pickup,
        driver_location: match.driver.current_location,
        notes: parking_spot
      )

  def arrive_at_return(%Match{} = match, parking_spot \\ nil),
    do:
      state_transition(
        match,
        :arrived_at_return,
        driver_location: match.driver.current_location,
        notes: parking_spot
      )

  def pickup(%Match{state: :arrived_at_pickup} = match),
    do: state_transition(match, :picked_up, driver_location: match.driver.current_location)

  def en_route_to_stop(%MatchStop{state: :pending} = stop),
    do: state_transition(stop, :en_route, driver_location: stop.match.driver.current_location)

  def arrive_at_stop(stop) do
    to_state = if stop.signature_required, do: :arrived, else: :signed

    with {:ok, %MatchStop{}} <-
           state_transition(stop, to_state, driver_location: stop.match.driver.current_location) do
      {:ok, Shipment.get_match(stop.match_id)}
    end
  end

  def sign_for_stop(stop) do
    with {:ok, %MatchStop{}} <-
           state_transition(stop, :signed, driver_location: stop.match.driver.current_location) do
      {:ok, Shipment.get_match(stop.match_id)}
    end
  end

  def deliver_stop(%MatchStop{state: state, match_id: match_id} = stop)
      when state in [:arrived, :signed] do
    with {:ok, %MatchStop{}} <-
           state_transition(stop, :delivered, driver_location: stop.match.driver.current_location) do
      {:ok, Shipment.get_match(match_id)}
    end
  end

  def undeliverable_stop(stop, reason) do
    with {:ok, %MatchStop{}} <-
           state_transition(stop, :undeliverable,
             notes: reason,
             driver_location: stop.match.driver.current_location
           ) do
      {:ok, Shipment.get_match(stop.match_id)}
    end
  end

  def complete_match(%{state: :picked_up} = match) do
    state_transition(match, :completed)
  end

  def complete_match(%{state: :arrived_at_return} = match) do
    mark_undeliverable_stops_as_returned(match.match_stops)
    state_transition(match, :completed)
  end

  def en_route_to_return(%{state: :picked_up} = match),
    do: state_transition(match, :en_route_to_return)

  def en_route_to_return(%{state: state} = match) when state in [:canceled, :admin_canceled],
    do: state_transition(match, :en_route_to_return)

  def en_route_to_return(_match), do: nil

  def charge_match(%Match{state: :completed} = match), do: state_transition(match, :charged)

  def charge_match(%Match{state: state}) when state in [:canceled, :admin_canceled], do: :ok

  def driver_cancel_match(match, reason)

  def driver_cancel_match(%Match{state: state} = match, reason)
      when state in [:accepted, :en_route_to_pickup, :arrived_at_pickup] do
    with true <- get_auto_cancel_on_driver_cancel(match),
         true <- canceled_too_late?(match) do
      state_transition(match, :canceled,
        notes: reason,
        driver_location: match.driver.current_location
      )
    else
      _ ->
        state_transition(match, :driver_canceled,
          notes: reason,
          driver_location: match.driver.current_location
        )
    end
  end

  def driver_cancel_match(%Match{}, _reason), do: {:error, :invalid_state}

  def unable_to_pickup_match(match, reason, driver_location \\ nil)

  def unable_to_pickup_match(%Match{state: state} = match, reason, driver_location)
      when state == :arrived_at_pickup do
    state_transition(match, :unable_to_pickup, notes: reason, driver_location: driver_location)
  end

  def unable_to_pickup_match(%Match{}, _reason, _driver_location), do: {:error, :invalid_state}

  def admin_cancel_match(%Match{state: :charged}), do: {:error, :invalid_state}

  def admin_cancel_match(
        %Match{} = match,
        reason \\ nil,
        code \\ nil
      ),
      do: state_transition(match, :admin_canceled, notes: reason, code: code)

  def shipper_cancel_match(match, reason \\ nil)

  def shipper_cancel_match(%Match{} = match, %{code: code, notes: notes}),
    do: state_transition(match, :canceled, notes: notes, code: code)

  def shipper_cancel_match(%Match{} = match, reason),
    do: state_transition(match, :canceled, notes: reason)

  def admin_renew_match(%Match{} = match) do
    mst = MatchStateTransition.get_latest(match.id)

    to =
      case mst.from do
        :completed -> :picked_up
        state -> state
      end

    WebhookSupervisor.start_match_webhook_sender(match, nil)
    state_transition(match, to)
  end

  def activate_upcoming_scheduled_matches do
    box_truck = Shipment.vehicle_class(:box_truck)
    threshold = future_scheduling_threshold(1)
    box_truck_threshold = future_scheduling_threshold(box_truck)

    query =
      from(m in Match,
        join: match_stops in assoc(m, :match_stops),
        where:
          m.state == "scheduled" and
            ((m.vehicle_class == ^box_truck and m.pickup_at <= ^box_truck_threshold) or
               (m.vehicle_class < ^box_truck and m.pickup_at <= ^threshold)),
        preload: [match_stops: match_stops]
      )

    matches =
      Repo.all(query)
      |> Enum.map(&state_transition!(&1, :assigning_driver))

    {:ok, Enum.count(matches)}
  end

  defp future_scheduling_threshold(vehicle_class) do
    if vehicle_class == Shipment.vehicle_class(:box_truck) do
      DateTime.utc_now() |> DateTime.add(@box_truck_scheduled_match_threshold)
    else
      DateTime.utc_now() |> DateTime.add(@scheduled_match_threshold)
    end
  end

  def force_transition_state(%Match{state: :unable_to_pickup} = match, desired_state) do
    {:ok, match} = force_transition(match, :picked_up)

    force_transition_state(match, desired_state)
  end

  def force_transition_state(%Match{state: current_state} = match, desired_state)
      when current_state != desired_state do
    current_index = get_state_index(current_state)
    desired_index = get_state_index(desired_state)
    next_index = current_index + 1

    if current_index <= desired_index do
      next_state =
        @all_states
        |> Enum.at(next_index)
        |> elem(0)

      match =
        case next_state do
          :completed ->
            match.match_stops
            |> Enum.each(fn stop ->
              case stop do
                %MatchStop{state: state} when state not in @completed_stop_states ->
                  force_transition_state(stop, :delivered)

                %MatchStop{state: :undeliverable} ->
                  state_transition(stop, :returned)

                stop ->
                  stop
              end
            end)

            Shipment.get_match(match.id)

          _ ->
            match
        end

      match =
        if get_state_index(match.state) < next_index do
          {:ok, match} = force_transition(match, next_state)
          match
        else
          match
        end

      force_transition_state(match, desired_state)
    else
      Shipment.get_match(match.id)
    end
  end

  def force_transition_state(%Match{} = match, _desired_state),
    do: Shipment.get_match(match.id)

  def force_transition_state(%MatchStop{state: current_state} = match_stop, desired_state)
      when current_state != desired_state do
    all_states = MatchStopState.all_indexes() |> Enum.sort(&(elem(&1, 1) < elem(&2, 1)))

    current_index = get_stop_state_index(current_state)
    desired_index = get_stop_state_index(desired_state)

    if current_index <= desired_index do
      next_state =
        all_states
        |> Enum.at(current_index + 1)
        |> elem(0)

      {:ok, match_stop} = force_transition(match_stop, next_state)
      force_transition_state(match_stop, desired_state)
    else
      Shipment.get_match_stop(match_stop.id)
    end
  end

  def force_transition_state(%MatchStop{} = match_stop, _desired_state),
    do: Shipment.get_match_stop(match_stop.id)

  def force_backwards_transition_state(%Match{} = match, desired_state) do
    {:ok, match} = force_transition(match, desired_state)

    Shipment.get_match(match.id) |> maybe_remove_driver()
  end

  def force_backwards_transition_state(%MatchStop{} = match_stop, desired_state) do
    {:ok, match_stop} = force_transition(match_stop, desired_state)

    Shipment.get_match_stop(match_stop.id)
  end

  def force_transition(%Match{} = match, next_state) do
    case next_state do
      :accepted -> accept_match(match)
      _ -> state_transition(match, next_state)
    end
  end

  def force_transition(%MatchStop{} = match_stop, next_state) do
    state_transition(match_stop, next_state)
  end

  defp state_transition!(%Match{} = match, state) do
    {:ok, match} = state_transition(match, state)
    match
  end

  defp state_transition!(%MatchStop{} = match_stop, state) do
    {:ok, match_stop} = state_transition(match_stop, state)
    match_stop
  end

  defp state_transition(match, state, opts \\ [])

  defp state_transition(%Match{} = match, state, opts),
    do: state_transition(state, match, opts)

  defp state_transition(state, %Match{} = match, opts) do
    save_state_transition(%{state: state}, match, opts)
  end

  defp state_transition(%MatchStop{} = match_stop, state, opts),
    do: state_transition(state, match_stop, opts)

  defp state_transition(state, %MatchStop{} = match_stop, opts) do
    save_state_transition(%{state: state}, match_stop, opts)
  end

  defp save_state_transition(attrs, %Match{} = match, opts) do
    %{state: to_state} = attrs
    state_transition_attrs = build_state_transition_attrs(match, to_state, opts)

    {:ok, {match, mst}} =
      Repo.transaction(fn ->
        {:ok, match} =
          match
          |> Match.state_changeset(attrs)
          |> Repo.update()

        {:ok, match_state_trans} =
          %MatchStateTransition{}
          |> MatchStateTransition.changeset(state_transition_attrs)
          |> Repo.insert()

        {match, match_state_trans}
      end)

    match = Shipment.get_match(match.id)

    broadcast_transition(match, mst)
    post_transition(match, mst)
    MatchNotifications.send_notifications(match, mst)
    post_transition(match, mst, :after)
    {:ok, Shipment.get_match(match.id)}
  end

  defp save_state_transition(
         %{state: to_state} = attrs,
         %MatchStop{} = stop,
         opts
       ) do
    state_transition_attrs = build_state_transition_attrs(stop, to_state, opts)

    {:ok, {stop, msst}} =
      Repo.transaction(fn ->
        {:ok, stop} =
          stop
          |> MatchStop.state_changeset(attrs)
          |> Repo.update()

        {:ok, msst} =
          %MatchStopStateTransition{}
          |> MatchStopStateTransition.changeset(state_transition_attrs)
          |> Repo.insert()

        {stop, msst}
      end)

    stop =
      stop
      |> Repo.preload(
        [
          items: [],
          destination_address: [],
          match: [:driver],
          recipient: []
        ],
        force: true
      )

    broadcast_transition(stop, msst)
    post_transition(stop, msst)
    MatchNotifications.send_notifications(stop, msst)
    post_transition(stop, msst, :after)
    {:ok, Shipment.get_match_stop(stop.id)}
  end

  defp build_state_transition_attrs(record, to, opts) do
    notes = Keyword.get(opts, :notes)
    code = Keyword.get(opts, :code)
    driver_location = Keyword.get(opts, :driver_location)

    driver_location_id = driver_location && Map.get(driver_location, :id)
    driver_location_inserted_at = driver_location && Map.get(driver_location, :inserted_at)

    record_key =
      case record do
        %Match{} -> :match_id
        %MatchStop{} -> :match_stop_id
      end

    %{
      record_key => record.id,
      from: record.state,
      to: to,
      notes: notes,
      code: code,
      driver_location_id: driver_location_id,
      driver_location_inserted_at: driver_location_inserted_at
    }
  end

  defp broadcast_transition(%Match{} = match, msst) do
    PubSub.broadcast!(FraytElixir.PubSub, "match_state_transitions", {match, msst})
    PubSub.broadcast!(FraytElixir.PubSub, "match_state_transitions:#{match.id}", {match, msst})
  end

  defp broadcast_transition(%MatchStop{} = match_stop, msst) do
    msst = msst |> Repo.preload(:match_stop)

    PubSub.broadcast!(
      FraytElixir.PubSub,
      "match_state_transitions:#{match_stop.match_id}",
      {match_stop, msst}
    )
  end

  defp post_transition(
         %Match{state: :assigning_driver, schedule_id: nil, state_transitions: %NotLoaded{}} =
           match,
         opts
       ),
       do: match |> Repo.preload(:state_transitions) |> post_transition(opts)

  defp post_transition(%Match{state: state} = match, mst)
       when state in [:assigning_driver, :scheduled] do
    if mst.to == :assigning_driver do
      if mst.from in [:pending, :scheduled, :inactive] do
        SLAs.calculate_match_slas(match, for: :frayt)
      end

      if !match.schedule_id do
        MatchSupervisor.start_assigning_drivers(match)
      end
    end

    if mst.from == :pending do
      MatchTags.set_new_match_tag(match)
    end
  end

  defp post_transition(
         %MatchStop{state: :pending, match_id: match_id},
         %MatchStateTransition{from: :en_route}
       ) do
    with %Match{match_stops: stops} = match <- Shipment.get_match(match_id),
         false <- Enum.any?(stops, fn %MatchStop{state: state} -> state == :en_route end) do
      MatchSupervisor.start_not_enroute_to_dropoff_match_notifier(match)
    end
  end

  defp post_transition(
         %Match{state: :accepted} = match,
         %MatchStateTransition{from: from}
       ) do
    MatchSupervisor.stop_assigning_drivers(match)

    MatchSupervisor.start_accepted(match)

    if from == :assigning_driver do
      {:ok, match} = SLAs.complete_match_slas(match, types: :acceptance)
      SLAs.calculate_match_slas(match, for: :driver)
    end
  end

  defp post_transition(%Match{state: :driver_canceled} = match, _mst) do
    {:ok, match} = SLAs.reset_match_slas(match, for: :frayt)
    {:ok, match} = SLAs.complete_match_slas(match, for: :driver)

    {:ok, match} = Match.remove_driver_changeset(match) |> Repo.update()

    state_transition!(match, :assigning_driver)
  end

  defp post_transition(%Match{state: state} = match, _mst)
       when state in [:en_route_to_pickup, :en_route_to_return],
       do: Shipment.update_eta(match)

  defp post_transition(%Match{state: :picked_up} = match, _mst) do
    SLAs.complete_match_slas(match, types: :pickup)
  end

  defp post_transition(
         %Match{state: state, match_stops: stops} = match,
         %{from: :picked_up, to: :canceled}
       )
       when state in [:admin_canceled, :canceled] do
    [stop | _] = stops
    stop = stop |> Repo.preload(match: :driver)
    undeliverable_stop(stop, "Match was canceled before delivery")
    en_route_to_return(match)

    SLAs.complete_match_slas(match, types: [:acceptance, :pickup, :delivery])
  end

  defp post_transition(%Match{state: state} = match, _mst)
       when state in [:admin_canceled, :canceled],
       do: SLAs.complete_match_slas(match, types: [:acceptance, :pickup, :delivery])

  defp post_transition(
         %MatchStop{state: :pending, match_id: match_id} = _match_stop,
         %MatchStopStateTransition{from: :en_route}
       ) do
    with %Match{match_stops: stops} = match <- Shipment.get_match(match_id),
         true <-
           Enum.all?(stops, fn %MatchStop{state: state} ->
             state != :en_route and state not in @completed_stop_states
           end) do
      MatchSupervisor.start_not_enroute_to_dropoff_match_notifier(match)
    end
  end

  defp post_transition(%MatchStop{state: :en_route, match_id: match_id} = stop, _) do
    match = Shipment.get_match(match_id)
    Shipment.update_eta(stop, match.driver)
    MatchSupervisor.stop_not_enroute_to_dropoff_match_notifier(match)
  end

  defp post_transition(%Match{state: :completed} = match, %{from: from}) when from == :charged do
    {:ok, match}
  end

  defp post_transition(%Match{state: :completed, match_stops: stops} = match, _) do
    Matches.update_match_price(match)

    Task.start_link(fn ->
      Drivers.update_driver_metrics(match.driver)
    end)

    if all_stops_undeliverable?(stops) do
      MatchTags.create_tag(match, :deadrun)
    end
  end

  defp post_transition(%Match{} = match, _), do: match

  defp post_transition(%MatchStop{state: state} = match_stop, _msst)
       when state in @completed_stop_states do
    with %{match_stops: stops, state: state} = match
         when state not in [:completed, :charged] <- Shipment.get_match(match_stop.match_id),
         true <- all_stops_completed?(stops) do
      if any_undeliverable_stops?(stops) do
        en_route_to_return(match)
      else
        {:ok, match} = complete_match(match)

        SLAs.complete_match_slas(match, types: :delivery)
      end
    end

    match_stop
  end

  defp post_transition(%MatchStop{} = match_stop, _), do: match_stop

  defp post_transition(
         %Match{state: state} = match,
         %MatchStateTransition{from: :picked_up, to: :canceled},
         :after
       )
       when state in [:admin_canceled, :canceled] do
    match
  end

  defp post_transition(
         %Match{state: state} = match,
         %MatchStateTransition{from: from_state},
         :after
       )
       when state in [:admin_canceled, :canceled] do
    stop_match_supervisor(match, from_state)
  end

  defp post_transition(%Match{} = match, %MatchStateTransition{from: :pending} = mst, :after) do
    Task.start_link(fn ->
      Hubspot.update_last_match(match, mst)
    end)
  end

  defp post_transition(%Match{} = match, _, _), do: match

  defp post_transition(item, _, _), do: item

  def mark_undeliverable_stops_as_returned(stops) do
    stops
    |> Enum.filter(&(&1.state == :undeliverable))
    |> Enum.map(&state_transition(&1, :returned))
  end

  @doc """
  Given a list of stops determines if all of them were marked as completed.
  """
  def all_stops_completed?(stops) do
    stops
    |> Enum.all?(&(&1.state in @completed_stop_states))
  end

  @doc """
  Given a list of stops determines if all of them were marked as undeliverable.
  """
  def all_stops_undeliverable?(stops) do
    stops
    |> Enum.all?(&(&1.state == :undeliverable))
  end

  def any_undeliverable_stops?(stops) do
    stops
    |> Enum.any?(&(&1.state == :undeliverable))
  end

  defp stop_match_supervisor(%Match{} = match, :assigning_driver),
    do: MatchSupervisor.stop_assigning_drivers(match)

  defp stop_match_supervisor(%Match{} = match, :accepted),
    do: MatchSupervisor.stop_not_picked_up_match_notifier(match)

  defp stop_match_supervisor(%Match{} = match, from_state)
       when from_state in [:en_route_to_pickup, :arrived_at_pickup],
       do: MatchSupervisor.stop_not_picked_up_match_notifier(match)

  defp stop_match_supervisor(%Match{} = match, :picked_up),
    do: MatchSupervisor.stop_not_enroute_to_dropoff_match_notifier(match)

  defp stop_match_supervisor(%MatchStop{match_id: match_id} = _match_stop, :pending) do
    with %Match{} = match <- Shipment.get_match(match_id) do
      MatchSupervisor.stop_not_enroute_to_dropoff_match_notifier(match)
    end
  end

  defp stop_match_supervisor(_, _), do: nil

  defp maybe_remove_driver(%Match{state: :assigning_driver} = match) do
    match
    |> Match.remove_driver_changeset()
    |> Repo.update!()
    |> Map.get(:id)
    |> Shipment.get_match()
  end

  defp maybe_remove_driver(match), do: match

  defp get_state_index(state), do: Enum.find_index(@all_states, fn {key, _} -> key == state end)

  defp get_stop_state_index(state),
    do: Enum.find_index(@all_stop_states, fn {key, _} -> key == state end)

  defp canceled_too_late?(match) do
    cancel_time_after_acceptance = get_auto_cancel_on_driver_cancel_time_after_acceptance(match)
    %{inserted_at: accepted_at} = Shipment.find_transition(match, :accepted, :desc)

    if accepted_at do
      result =
        Timex.now()
        |> Timex.add(Timex.Duration.from_milliseconds(cancel_time_after_acceptance))
        |> Timex.compare(accepted_at)

      result > 0
    else
      false
    end
  end

  defp get_auto_cancel_on_driver_cancel(nil), do: false

  defp get_auto_cancel_on_driver_cancel(%Company{auto_cancel_on_driver_cancel: auto_cancels}),
    do: auto_cancels

  defp get_auto_cancel_on_driver_cancel(%Match{contract: contract} = match)
       when is_empty(contract),
       do:
         match
         |> Accounts.get_match_company()
         |> get_auto_cancel_on_driver_cancel()

  defp get_auto_cancel_on_driver_cancel(%Match{contract: _contract} = match) do
    case CustomContracts.get_auto_cancel_on_driver_cancel(match) do
      {:ok, cancels} -> cancels
      _ -> match |> Accounts.get_match_company() |> get_auto_cancel_on_driver_cancel()
    end
  end

  defp get_auto_cancel_on_driver_cancel_time_after_acceptance(nil), do: 0

  defp get_auto_cancel_on_driver_cancel_time_after_acceptance(%Company{
         auto_cancel_on_driver_cancel_time_after_acceptance: cancel_time
       }),
       do: cancel_time

  defp get_auto_cancel_on_driver_cancel_time_after_acceptance(%Match{contract: contract} = match)
       when is_empty(contract),
       do:
         match
         |> Accounts.get_match_company()
         |> get_auto_cancel_on_driver_cancel_time_after_acceptance()

  defp get_auto_cancel_on_driver_cancel_time_after_acceptance(%Match{contract: _} = match) do
    case CustomContracts.get_auto_cancel_on_driver_cancel_time_after_acceptance(match) do
      {:ok, cancel_time} ->
        cancel_time

      _ ->
        match
        |> Accounts.get_match_company()
        |> get_auto_cancel_on_driver_cancel_time_after_acceptance()
    end
  end
end
