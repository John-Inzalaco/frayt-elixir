defmodule FraytElixir.Shipment do
  @moduledoc """
  The Shipment context.
  """
  require Logger
  import Ecto.Query, warn: false
  alias FraytElixir.Repo
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.TomTom

  alias FraytElixir.Shipment.{
    VehicleClass,
    Match,
    Address,
    MatchWorkflow,
    MatchFee,
    MatchStop,
    MatchStopState,
    MatchStateTransition,
    MatchStopStateTransition,
    MatchState,
    ETA
  }

  alias FraytElixir.Accounts.{Company, Location, Shipper}

  alias FraytElixir.Matches
  alias FraytElixir.PaginationQueryHelpers
  alias FraytElixir.Drivers.{Driver, Vehicle}

  alias Ecto.Association.NotLoaded
  alias FraytElixir.AtomizeKeys

  @distance Application.compile_env(
              :frayt_elixir,
              :distance_calculator,
              &TomTom.Routing.calculate_route/2
            )

  @cancelable_states MatchState.cancelable_range()
  @restricted_cancelable_states MatchState.restricted_cancelable_range()
  @canceled_states MatchState.canceled_range()

  def distance(route),
    do: @distance.(route, avoid: "ferries")

  def vehicle_classes(index), do: VehicleClass.get_attribute(index, :type)

  def vehicle_class(class) when is_atom(class),
    do: VehicleClass.get_attribute(class, :vehicle_class)

  @service_levels %{
    1 => :dash,
    2 => :same_day
  }

  def service_level(index), do: @service_levels[index]

  @default_pagination_params %{page: 0, per_page: 10, order: :desc, order_by: :inserted_at}
  @default_list_shipper_matches_params Map.merge(@default_pagination_params, %{
                                         states: :visible,
                                         types: :all
                                       })

  def get_attribute(attribute_name) when attribute_name == :vehicle_classes,
    do: VehicleClass.get_vehicles()

  def get_attribute(attribute_name) when attribute_name == :service_levels, do: @service_levels

  def exclude_pending_matches(query),
    do:
      from(match in query,
        where: match.state != "pending"
      )

  def list_matches, do: Match |> Repo.all()

  def list_matches(filters) do
    query = Map.get(filters, :query)
    states = Map.get(filters, :states)
    types = Map.get(filters, :types)
    shipper_id = Map.get(filters, :shipper_id)
    company_id = Map.get(filters, :company_id)
    contract_id = Map.get(filters, :contract_id)
    driver_id = Map.get(filters, :driver_id)
    only_mine = Map.get(filters, :only_mine)
    stops = Map.get(filters, :stops)
    start_date = Map.get(filters, :start_date)
    end_date = Map.get(filters, :end_date)
    sla = Map.get(filters, :sla)
    vehicle_class = Map.get(filters, :vehicle_class)

    Match
    |> exclude_pending_matches()
    |> Match.filter_by_dates(start_date, end_date)
    |> Match.filter_by_query(query)
    |> Match.filter_by_network_operator(only_mine)
    |> Match.filter_by_transaction_type(types)
    |> Match.filter_by_state(states)
    |> Match.filter_by_company(company_id)
    |> Match.filter_by_contract(contract_id)
    |> Match.filter_by_shipper(shipper_id)
    |> Match.filter_by_driver(driver_id)
    |> Match.filter_by_stops(stops)
    |> Match.filter_by_sla(sla)
    |> Match.filter_by_vehicle_type(vehicle_class)
    |> PaginationQueryHelpers.list_record(filters, [
      :origin_address,
      :shipper,
      :tags,
      :slas,
      :contract,
      :eta,
      network_operator: [:user],
      driver: [:metrics],
      match_stops: [:destination_address, :eta]
    ])
  end

  def list_shipper_matches(%Shipper{} = shipper),
    do: list_shipper_matches(shipper, @default_list_shipper_matches_params)

  def list_shipper_matches(shipper, params),
    do: build_shipper_matches_query(Match, shipper, params)

  defp build_shipper_matches_query(
         query,
         shipper,
         %{
           page: page,
           per_page: per_page,
           order: order,
           order_by: order_by
         } = params
       )
       when order_by in [:inserted_at, :total_distance] and order in [:asc, :desc] and
              is_integer(page) and is_integer(per_page) do
    location_id = Map.get(params, :location_id)
    shipper_id = Map.get(params, :shipper_id)

    query
    |> Match.excluding_pending()
    |> Match.filter_by_permissions(shipper, location_id, shipper_id)
    |> build_shipper_list_filters(params)
    |> PaginationQueryHelpers.list_record(params, [
      :origin_address,
      :sender,
      match_stops: [:destination_address, :recipient]
    ])
  end

  defp build_shipper_matches_query(
         query,
         shipper,
         %{
           page: _page,
           per_page: _per_page,
           order: _order,
           order_by: _order_by
         }
       ),
       do: build_shipper_matches_query(query, shipper, @default_list_shipper_matches_params)

  defp build_shipper_matches_query(query, shipper, %{} = params),
    do:
      build_shipper_matches_query(
        query,
        shipper,
        @default_list_shipper_matches_params |> Map.merge(params)
      )

  defp build_shipper_list_filters(query, params),
    do:
      params
      |> Enum.reduce(query, fn {key, value}, q -> build_shipper_list_filter(q, key, value) end)

  defp build_shipper_list_filter(query, :search, search), do: Match.filter_by_query(query, search)
  defp build_shipper_list_filter(query, :states, state), do: Match.filter_by_state(query, state)

  defp build_shipper_list_filter(query, _, _), do: query

  def list_matches_for_company(
        company_id,
        pagination_params
      ) do
    Match
    |> Match.where_company_is(company_id)
    |> PaginationQueryHelpers.api_paginate(pagination_params)
    |> Repo.all()
    |> Repo.preload([:origin_address, :sender, match_stops: [:destination_address, :recipient]])
  end

  @doc """
  Gets a single match.

  Raises `Ecto.NoResultsError` if the Match does not exist.

  ## Examples

      iex> get_match!(123)
      %Match{}

      iex> get_match!(456)
      ** (Ecto.NoResultsError)

  """
  def get_match!(id), do: Match |> Repo.get!(id) |> preload_match()

  def get_match(id) do
    Match
    |> Repo.get(id)
    |> preload_match()
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_match_stop(nil), do: nil

  def get_match_stop(id) do
    MatchStop
    |> Repo.get(id)
    |> Repo.preload([:destination_address, :items, :recipient])
  rescue
    Ecto.Query.CastError -> nil
  end

  def update_eta(%Match{driver: driver} = match), do: update_eta(match, driver)

  def update_eta(match_or_stop, driver) do
    with {:ok, route} <- build_eta_route(driver, match_or_stop),
         %DateTime{} = arrive_at <- calculate_arrival_time(route) do
      change_eta(match_or_stop, arrive_at) |> Repo.insert_or_update()
    end
  end

  defp calculate_arrival_time(route) do
    with {:ok, _total, _dist, duration} <- calculate_distance(route) do
      DateTime.utc_now() |> DateTime.add(duration, :second)
    end
  end

  def change_eta(%Match{} = match, arrive_at) do
    attrs = %{arrive_at: arrive_at, match_id: match.id}

    change_eta(attrs)
  end

  def change_eta(%MatchStop{} = stop, arrive_at) do
    attrs = %{arrive_at: arrive_at, stop_id: stop.id}

    change_eta(attrs)
  end

  def change_eta(%ETA{} = eta, arrive_at),
    do: ETA.changeset(eta, %{arrive_at: arrive_at})

  def change_eta(attrs) do
    attrs = AtomizeKeys.atomize_keys(attrs)

    eta =
      cond do
        is_binary(attrs[:id]) ->
          get_eta(attrs[:id])

        is_binary(attrs[:match_id]) ->
          Repo.get_by(ETA, match_id: attrs[:match_id])

        is_binary(attrs[:stop_id]) ->
          Repo.get_by(ETA, stop_id: attrs[:stop_id])

        true ->
          nil
      end

    eta = eta || %ETA{}

    ETA.changeset(eta, attrs)
  end

  def get_eta(id), do: Repo.get(ETA, id)

  def get_active_eta(%Match{state: state, eta: %ETA{} = eta})
      when state in [:en_route_to_pickup, :en_route_to_return] do
    updated_at = DateTime.from_naive!(eta.updated_at, "Etc/UTC")
    reload? = DateTime.utc_now() |> DateTime.diff(updated_at, :second) > 30

    if(reload?, do: get_eta(eta.id), else: eta)
  end

  def get_active_eta(%Match{state: :picked_up, match_stops: stops} = _match) do
    case Enum.find(stops, &(&1.state == :en_route)) do
      %MatchStop{eta: %ETA{} = eta} ->
        updated_at = DateTime.from_naive!(eta.updated_at, "Etc/UTC")
        reload? = DateTime.utc_now() |> DateTime.diff(updated_at, :second) > 30

        if(reload?, do: get_eta(eta.id), else: eta)

      _ ->
        nil
    end
  end

  def get_active_eta(_), do: nil

  defp build_eta_route(driver, destination) do
    driver_coords = get_coordinates(driver)
    destination_coords = get_coordinates(destination)

    if driver_coords && destination_coords do
      {:ok, [driver_coords, destination_coords]}
    else
      :error
    end
  end

  defp get_coordinates(%ETA{match: %Match{} = match}),
    do: get_coordinates(match)

  defp get_coordinates(%ETA{stop: %MatchStop{} = stop}),
    do: get_coordinates(stop)

  defp get_coordinates(%Driver{current_location: loc}),
    do: get_coordinates(loc)

  defp get_coordinates(%Match{origin_address: loc}),
    do: get_coordinates(loc)

  defp get_coordinates(%MatchStop{destination_address: loc}),
    do: get_coordinates(loc)

  defp get_coordinates(%{geo_location: point}),
    do: get_coordinates(point)

  defp get_coordinates(%Geo.Point{coordinates: {lng, lat}}), do: {lat, lng}

  defp get_coordinates(_), do: nil

  def get_current_match_stop(%Match{match_stops: match_stops}) do
    incomplete_stops = Enum.filter(match_stops, &(&1.state not in [:delivered, :undeliverable]))

    case incomplete_stops do
      [] ->
        nil

      stops ->
        Enum.min_by(stops, &get_current_stop_priority/1)
    end
  end

  defp get_current_stop_priority(%MatchStop{index: index, state: :pending}), do: index
  defp get_current_stop_priority(_match_stop), do: -1

  def get_match_payment_totals(id) do
    Match
    |> Match.calculate_match_payment_totals(id)
    |> Repo.one()
  end

  def preload_match(match, [force: force?] \\ [force: false]),
    do:
      match
      |> Repo.preload(
        [
          :origin_address,
          [match_stops: [:destination_address, :items, :recipient, :eta]],
          {:match_stops, from(ms in MatchStop, order_by: ms.index)},
          [shipper: [:user, location: [company: :contracts]]],
          [driver: [:user, :vehicles, :metrics, :current_location]],
          [preferred_driver: [:user, :vehicles, :metrics]],
          {:state_transitions, from(s in MatchStateTransition, order_by: s.inserted_at)},
          [network_operator: [:user]],
          [payment_transactions: [:driver_bonus]],
          :coupon,
          :tags,
          :notification_batches,
          :fees,
          :sender,
          :market,
          :slas,
          [contract: [:cancellation_codes]],
          :eta
        ],
        force: force?
      )

  def get_shipper_match(%Shipper{id: shipper_id}, id),
    do: get_shipper_match(shipper_id, id)

  def get_shipper_match(nil, id) do
    from(m in Match,
      where: m.id == ^id and is_nil(m.shipper_id)
    )
    |> Repo.one()
    |> preload_match()
  end

  def get_shipper_match(shipper_id, id) do
    from(m in Match,
      where: m.id == ^id and (is_nil(m.shipper_id) or m.shipper_id == ^shipper_id)
    )
    |> Repo.one()
    |> preload_match()
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_live_stop_state(%Match{match_stops: stops}), do: get_live_stop_state(stops)

  def get_live_stop_state([]), do: nil

  def get_live_stop_state([%MatchStop{} | _] = match_stops) do
    cond do
      Enum.all?(match_stops, &(&1.state in MatchStopState.completed_range())) ->
        :delivered

      Enum.any?(match_stops, &(&1.state in MatchStopState.live_range())) ->
        Enum.find(match_stops, &(&1.state in MatchStopState.live_range())) |> (& &1.state).()

      true ->
        :pending
    end
  end

  def match_fees_for(match, user_type) do
    field = get_fee_field(user_type)

    match
    |> Map.get(:fees, [])
    |> Enum.reject(&(Map.get(&1, field) == 0))
  end

  def find_match_fee(match, type), do: Enum.find(match.fees, nil, &(&1.type == type))

  def get_match_fee_price(%Match{fees: %NotLoaded{}} = match, type, user_type),
    do: match |> Repo.preload(:fees) |> get_match_fee_price(type, user_type)

  def get_match_fee_price(match, type, user_type) do
    field = get_fee_field(user_type)

    case find_match_fee(match, type) do
      nil -> nil
      %MatchFee{} = fee -> Map.get(fee, field)
    end
  end

  defp get_fee_field(:shipper), do: :amount
  defp get_fee_field(:driver), do: :driver_amount

  defp get_deprecated_live_state(match_stops) do
    with %MatchStop{} = stop <- Enum.find(match_stops, &(&1.state in MatchStopState.live_range())) do
      case stop.state do
        :en_route -> :en_route_to_dropoff
        :arrived -> :arrived_at_dropoff
        state -> state
      end
    end
  end

  def get_deprecated_match_state(%Match{state: :picked_up, match_stops: stops}) do
    cond do
      Enum.any?(stops, &(&1.state in MatchStopState.live_range())) ->
        get_deprecated_live_state(stops)

      Enum.any?(stops, &(&1.state in MatchStopState.completed_range())) ->
        :en_route_to_dropoff

      true ->
        :picked_up
    end
  end

  def get_deprecated_match_state(%Match{state: :completed}),
    do: :delivered

  def get_deprecated_match_state(%Match{state: state}), do: state

  @fallback_company_settings %{
    origin_photo_required: false,
    destination_photo_required: false,
    autoselect_vehicle_class: false,
    signature_required: false,
    default_contract_id: nil,
    id: nil
  }

  def get_company_settings(nil), do: @fallback_company_settings

  def get_company_settings(%Shipper{} = shipper) do
    %{
      origin_photo_required: origin_photo_required,
      destination_photo_required: destination_photo_required,
      autoselect_vehicle_class: autoselect_vehicle_class,
      signature_required: signature_required,
      default_contract_id: default_contract_id,
      id: company_id
    } =
      shipper
      |> Repo.preload(location: :company)
      |> Map.get(:location)
      |> case do
        nil -> %{}
        l -> l
      end
      |> Map.get(:company)
      |> case do
        nil -> @fallback_company_settings
        c -> c
      end

    %{
      origin_photo_required: origin_photo_required == true,
      destination_photo_required: destination_photo_required == true,
      autoselect_vehicle_class: autoselect_vehicle_class == true,
      signature_required: signature_required == true,
      default_contract_id: default_contract_id,
      id: company_id
    }
  end

  def get_company_shipper(nil), do: nil

  def get_company_shipper(%Company{locations: []}), do: nil

  def get_company_shipper(%Company{locations: %NotLoaded{}} = company),
    do: company |> Repo.preload(locations: [:shippers]) |> get_company_shipper()

  def get_company_shipper(%Company{
        locations: [%Location{shippers: [%Shipper{} = shipper | _]} | _]
      }),
      do: shipper

  def calculate_distance(route) do
    case distance(route) do
      {:ok, results} -> extract_distance(results)
      {:error, message} -> {:error, message}
    end
  end

  def convert_to_miles(meters) do
    meters
    |> (&(&1 * 3.2808 / 5280)).()
    |> Float.ceil(1)
  end

  defp extract_distance(%{
         "routes" => [
           %{
             "legs" => legs,
             "summary" => %{
               "lengthInMeters" => total_meters,
               "travelTimeInSeconds" => duration
             }
           }
         ]
       }) do
    distances =
      legs
      |> Enum.reduce([], fn %{"summary" => %{"lengthInMeters" => meters}}, acc ->
        acc ++ [convert_to_miles(meters)]
      end)

    {:ok, convert_to_miles(total_meters), distances, trunc(duration)}
  end

  def update_match_slack_thread(%Match{} = match, slack_thread_id) do
    match
    |> Match.slack_thread_changeset(%{slack_thread_id: slack_thread_id})
    |> Repo.update()
  end

  def match_transitioned_at(match_or_stop, states, order \\ :desc) do
    case find_transition(match_or_stop, states, order) do
      %{inserted_at: inserted_at} -> inserted_at
      _ -> nil
    end
  end

  def find_transition(match_or_stop, state, order \\ :asc)

  def find_transition(match_or_stop, states, order) when is_list(states),
    do:
      match_or_stop
      |> Repo.preload(:state_transitions)
      |> Map.get(:state_transitions)
      |> Enum.filter(&(&1.to in states))
      |> find_transition_by(order)

  def find_transition(match, state, order), do: find_transition(match, [state], order)

  def match_authorized_time(%Match{scheduled: scheduled} = match) do
    state =
      case scheduled do
        true -> :scheduled
        false -> :assigning_driver
      end

    match_transitioned_at(match, state, :asc)
  end

  def match_canceled_transition(match, order \\ :asc) do
    canceled_at = find_transition(match, :canceled, order)
    admin_canceled_at = find_transition(match, :admin_canceled, order)

    find_transition_by([canceled_at, admin_canceled_at], order)
  end

  defp find_transition_by(transitions, order),
    do:
      transitions
      |> Enum.filter(& &1)
      |> Enum.sort_by(& &1.inserted_at, {order, NaiveDateTime})
      |> List.first()

  def get_match_shortcode(%Match{shortcode: nil} = match), do: match.id |> get_match_shortcode()
  def get_match_shortcode(%Match{shortcode: shortcode}), do: shortcode

  def get_match_shortcode(id) when is_bitstring(id) do
    id |> String.slice(0..7) |> String.upcase()
  end

  def get_match_shortcode(nil), do: nil

  def preload_batch(batch), do: preload_batch(batch, force: false)

  def preload_batch(batch, force: force?),
    do:
      batch
      |> Repo.preload(
        [
          :matches,
          :match_stops,
          :location,
          :shipper
        ],
        force: force?
      )

  def get_address(address_id), do: Repo.get(Address, address_id)

  def get_recent_addresses(nil), do: []

  def get_recent_addresses(shipper) do
    origin_query =
      from(a in Address,
        join: m in "matches",
        on: m.origin_address_id == a.id,
        where: m.shipper_id == type(^shipper.id, :binary_id)
      )

    destination_query =
      from(a in Address,
        join: m in "matches",
        join: ms in "match_stops",
        on: ms.destination_address_id == a.id,
        on: ms.match_id == m.id,
        where: m.shipper_id == type(^shipper.id, :binary_id)
      )

    (Repo.all(origin_query) ++ Repo.all(destination_query))
    |> Enum.map(& &1.formatted_address)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.map(fn {formatted_address, _count} -> formatted_address end)
  end

  def create_address(attrs) do
    %Address{}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  def create_address_for_location(attrs) do
    %Address{}
    |> Address.admin_geocoding_changeset(attrs)
    |> Repo.insert()
  end

  def allowable_vehicle?(match, vehicles) when is_list(vehicles) do
    vehicles |> Enum.any?(&allowable_vehicle?(match, &1))
  end

  def allowable_vehicle?(%Match{vehicle_class: match_vehicle_class}, %Vehicle{
        vehicle_class: vehicle_class
      })
      when vehicle_class >= match_vehicle_class,
      do: true

  def allowable_vehicle?(_, _), do: false

  def is_holiday_match(match) do
    case get_match_holidays(match) do
      {:ok, holidays} -> length(holidays) > 0
      {:error, _} -> false
    end
  end

  def get_match_holidays(%Match{timezone: timezone} = match) do
    date =
      match
      |> match_departure_time()
      |> DisplayFunctions.datetime_with_timezone(timezone)
      |> NaiveDateTime.to_date()

    Holidefs.on(:fed, date)
  end

  def match_departure_time(%Match{scheduled: true, pickup_at: pickup_at})
      when not is_nil(pickup_at),
      do: pickup_at

  def match_departure_time(%Match{scheduled: false} = match) do
    transition =
      match
      |> Repo.preload(:state_transitions)
      |> Map.get(:state_transitions)
      |> Enum.sort_by(&DateTime.to_unix(DateTime.from_naive!(&1.inserted_at, "Etc/UTC")), :desc)
      |> Enum.find(fn t -> t.to == :assigning_driver end)

    case transition do
      nil -> NaiveDateTime.utc_now()
      t -> t.inserted_at
    end
  end

  def admin_cancel_match(match, reason, code \\ nil, charge_attrs \\ nil) do
    with {:ok, match} <-
           MatchWorkflow.admin_cancel_match(match, reason, code) do
      Matches.apply_cancel_charge(match, charge_attrs)
    end
  end

  def shipper_cancel_match(match, reason \\ nil, opts \\ [])

  def shipper_cancel_match(%Match{contract_id: contract_id} = match, reason, _)
      when not is_nil(contract_id) do
    %Match{contract: contract, state: state} = match = Repo.preload(match, :contract)

    if state in contract.allowed_cancellation_states do
      with {:ok, match} <-
             MatchWorkflow.shipper_cancel_match(match, reason) do
        Matches.apply_cancel_charge(match)
      end
    else
      {:error, :invalid_state, "Match cannot be cancelled in this state"}
    end
  end

  def shipper_cancel_match(%Match{state: state} = match, reason, [])
      when state in @cancelable_states,
      do: MatchWorkflow.shipper_cancel_match(match, reason)

  def shipper_cancel_match(%Match{state: state} = match, reason, restricted: true)
      when state in @restricted_cancelable_states,
      do: shipper_cancel_match(match, reason)

  def shipper_cancel_match(%Match{state: state}, _, _) when state in @canceled_states,
    do: {:error, :invalid_state, "Match has already been canceled"}

  def shipper_cancel_match(_, _, []),
    do: {:error, :invalid_state, "A Match cannot be canceled after it is picked up"}

  def shipper_cancel_match(_, _, restricted: true),
    do: {:error, :invalid_state, "Match cannot be canceled when driver has accepted."}

  def most_recent_transition(%MatchStop{id: match_stop_id}, state) when is_atom(state) do
    state = Atom.to_string(state)

    from(msst in MatchStopStateTransition,
      where: msst.match_stop_id == ^match_stop_id and msst.to == ^state,
      order_by: [desc: :inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def most_recent_transition(%Match{id: match_id}, state) when is_atom(state) do
    state = Atom.to_string(state)

    from(mst in MatchStateTransition,
      where: mst.match_id == ^match_id and mst.to == ^state,
      order_by: [desc: :inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_and_lock_match(id) do
    Match
    |> where([m], m.id == ^id)
    |> lock("FOR UPDATE SKIP LOCKED")
    |> Repo.one()
    |> case do
      %Match{} = match -> match
      nil -> {:error, "No match found"}
    end
  end
end
