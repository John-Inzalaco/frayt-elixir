defmodule FraytElixir.Drivers do
  @moduledoc """
  The Drivers context.
  """

  import Ecto.Query, warn: false
  import Geo.PostGIS
  import FraytElixir.DistanceConversion
  import FraytElixir.Guards

  alias FraytElixir.Notifications.MatchNotifications
  alias FraytElixir.DriverDocuments
  alias FraytElixir.Markets
  alias FraytElixir.Screenings.BackgroundCheck

  alias FraytElixir.Drivers.{
    Driver,
    Vehicle,
    DriverLocation,
    DriverMetrics,
    DriverState,
    HiddenCustomer,
    DriverStateTransition
  }

  alias FraytElixir.{
    Accounts,
    GeocodedAddressHelper,
    PaginationQueryHelpers,
    Repo,
    Shipment,
    Email,
    Mailer,
    Matches
  }

  alias Accounts.{User, Company, Shipper}
  alias FraytElixirWeb.UploadHelper
  alias Ecto.Association.NotLoaded

  alias Shipment.{
    Match,
    MatchWorkflow,
    MatchState,
    MatchStopState,
    HiddenMatch,
    MatchStateTransition,
    MatchStop,
    VehicleClass,
    BarcodeReadings
  }

  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Matches
  alias FraytElixir.Rating

  @disabled_states DriverState.disabled_states()
  @live_match_states MatchState.live_range()
  @completed_match_states MatchState.completed_range()

  @accepted_match_limit 3

  def get_current_accepted_match_limit, do: @accepted_match_limit

  def get_driver_vehicle(driver, id), do: Repo.get_by(Vehicle, id: id, driver_id: driver.id)

  def get_vehicle(vehicle_id) do
    from(v in Vehicle,
      where: v.id == ^vehicle_id
    )
    |> Repo.one()
  end

  def update_vehicle_cargo_capacity(%Vehicle{} = vehicle, attrs) do
    vehicle
    |> Vehicle.cargo_capacity_changeset(attrs)
    |> Repo.update()
  end

  def update_vehicle(%Vehicle{} = vehicle, attrs) do
    vehicle
    |> Vehicle.changeset(attrs)
    |> Repo.update()
  end

  def touch_vehicle(%Vehicle{} = vehicle) do
    updated_at = DateTime.utc_now() |> DateTime.to_naive()

    vehicle
    |> Ecto.Changeset.cast(%{updated_at: updated_at}, [:updated_at])
    |> Repo.update()
  end

  def geocode_address(address) do
    case GeocodedAddressHelper.get_geocoded_address(address) do
      {:ok,
       %{"results" => [%{"geometry" => %{"location" => %{"lat" => lat, "lng" => lng}}} | _tl]}} ->
        %Geo.Point{coordinates: {lng, lat}}

      _ ->
        :not_found
    end
  end

  defp build_capacity_query(%{pickup_address: pickup_address} = attrs)
       when not is_empty(pickup_address) do
    attrs
    |> Map.put(
      :pickup_point,
      case pickup_address do
        "" -> nil
        _ -> geocode_address(pickup_address)
      end
    )
    |> Map.delete(:pickup_address)
    |> build_capacity_query()
  end

  defp build_capacity_query(%{pickup_point: nil, search_radius: radius}) when not is_nil(radius),
    do: {:error, :no_address}

  defp build_capacity_query(%{pickup_point: :not_found}),
    do: {:error, :address_not_found}

  defp build_capacity_query(%{
         pickup_point: pickup_point,
         search_radius: search_radius,
         vehicle_types: vehicle_types,
         driver_location: driver_location,
         query: nil
       }),
       do:
         {:ok,
          Driver
          |> Driver.approved_drivers()
          |> Driver.filter_by_vehicle_type(vehicle_types)
          |> Driver.filter_by_pickup(driver_location, pickup_point, search_radius), pickup_point}

  defp build_capacity_query(%{
         query: query,
         pickup_point: pickup_point,
         driver_location: driver_location
       }),
       do:
         {:ok,
          Driver
          |> Driver.approved_drivers()
          |> Driver.filter_by_query(query)
          |> Driver.filter_by_pickup(driver_location, pickup_point, nil), pickup_point}

  def list_capacity(
        %{
          page: page,
          per_page: per_page
        } = attrs
      ) do
    case build_capacity_query(attrs) do
      {:ok, partial_query, pickup_point} ->
        results =
          partial_query
          |> PaginationQueryHelpers.paginate(page, per_page)
          |> Repo.all()
          |> Repo.preload([
            :user,
            :address,
            :current_location,
            :metrics,
            images: DriverDocuments.latest_driver_documents_query(),
            vehicles: [images: DriverDocuments.latest_vehicle_documents_query()]
          ])

        pages =
          partial_query
          |> PaginationQueryHelpers.page_count_without_select(per_page)

        {results, pages, %{pickup_point: pickup_point, capacity_error: nil}}

      {:error, error} ->
        {[], 0, %{pickup_point: nil, capacity_error: error}}
    end
  end

  def list_capacity_drivers(attrs, limit \\ 100) do
    with {:ok, partial_query, pickup_point} <- build_capacity_query(attrs) do
      results =
        partial_query
        |> Driver.filter_by_sms_opt_out(false)
        |> PaginationQueryHelpers.paginate(0, limit)
        |> Repo.all()

      {:ok, results, %{pickup_point: pickup_point}}
    end
  end

  def validate_match_assignment(driver_id, match_id) do
    match_ids =
      Driver
      |> Driver.full_match_id_on_driver(driver_id, match_id)
      |> Repo.all()

    Enum.count(match_ids)
    |> case do
      0 -> {:error, "match not found"}
      1 -> {:ok, List.first(match_ids)}
      _ -> {:error, "multiple matches found", match_ids}
    end
  end

  def active_matches_qry(driver_id) do
    from(m in Match,
      where: m.state in ^@live_match_states and m.driver_id == ^driver_id
    )
  end

  def active_matches_count(driver_id) do
    qry =
      from(amq in active_matches_qry(driver_id),
        select: count(amq)
      )

    qry |> Repo.one()
  end

  def get_poorly_rated_matches(id),
    do:
      Driver.poorly_rated_matches(id)
      |> Repo.all()

  def list_drivers(
        params,
        preload \\ [:vehicles, :address, :metrics, :market]
      ) do
    query = Map.get(params, :query)
    order = Map.get(params, :order)
    state = Map.get(params, :state)
    document_state = Map.get(params, :document_state)
    background_state = Map.get(params, :background_check_state)
    vehicle_class = Map.get(params, :vehicle_class)
    market_id = Map.get(params, :market_id)

    query =
      Driver
      |> Driver.filter_by_query(query)
      |> Driver.filter_by_state(state)
      |> Driver.filter_by_vehicle_type(vehicle_class)
      |> Driver.filter_by_background_check_state(background_state)
      |> Driver.filter_by_document_state(document_state)
      |> Driver.filter_by_market_id(market_id)

    from(m in query,
      left_join: st in DriverStateTransition,
      on: st.driver_id == m.id and st.from == :applying and st.to == :pending_approval,
      order_by: [{^order, st.inserted_at}, {^order, m.inserted_at}],
      select_merge: %{applied_at: st.inserted_at}
    )
    |> PaginationQueryHelpers.list_record(params, preload)
  end

  @spec list_past_drivers_for_shipper(Ecto.UUID.t()) :: [Driver.t()]
  def list_past_drivers_for_shipper(shipper_id) do
    from(driver in Driver,
      as: :driver,
      join: match in assoc(driver, :matches),
      where: match.shipper_id == ^shipper_id,
      where: match.state in ^@completed_match_states,
      distinct: driver.id,
      preload: [:user, :current_location, :vehicles]
    )
    |> filter_hidden_customers(:all, %Match{shipper_id: shipper_id})
    |> Repo.all()
  end

  @spec list_drivers_for_shipper(Shipper.t(), map()) :: [Driver.t()]
  def list_drivers_for_shipper(shipper, filter \\ %{}) do
    case filter do
      %{email: email} ->
        driver = get_preferred_driver_by_email(email, shipper.id, [:user])

        if driver, do: [driver], else: []

      _ ->
        list_past_drivers_for_shipper(shipper.id)
    end
  end

  @spec get_preferred_driver_by_email(String.t(), Ecto.UUID.t(), [atom()]) :: Driver.t() | nil
  def get_preferred_driver_by_email(email, shipper_id, preloads \\ []) do
    Driver
    |> Driver.get_driver_by_email(email)
    |> filter_hidden_customers(:all, %Match{shipper_id: shipper_id})
    |> Repo.one()
    |> Repo.preload(preloads)
  end

  @doc """
  Gets a single driver.

  Raises `Ecto.NoResultsError` if the Driver does not exist.

  ## Examples

      iex> get_driver!(123)
      %Driver{}

      iex> get_driver!(456)
      ** (Ecto.NoResultsError)

  """
  def get_driver!(id), do: get_driver!(id, true)

  def get_driver!(id, :no_matches), do: get_driver!(id, false)

  def get_driver!(id, with_matches?),
    do: Repo.get!(Driver, id) |> Repo.preload(driver_preloads(with_matches?))

  def get_driver(id),
    do: Repo.get(Driver, id) |> Repo.preload(driver_preloads(false))

  def get_driver_metrics(%Driver{metrics: %NotLoaded{}} = driver),
    do: driver |> Repo.preload(:metrics) |> get_driver_metrics()

  def get_driver_metrics(%Driver{metrics: metrics}), do: metrics

  def get_driver_metrics(_), do: nil

  defp driver_preloads(false),
    do: [
      :user,
      :address,
      :metrics,
      :market,
      {:vehicles, from(v in Vehicle, order_by: v.inserted_at)}
    ]

  defp driver_preloads(true), do: driver_preloads(false) ++ [:matches]

  @doc """
  Creates a driver.

  ## Examples

      iex> create_driver(%{field: value})
      {:ok, %Driver{}}

      iex> create_driver(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_driver(%{market_id: market_id, vehicle_class: vehicle_class} = attrs) do
    {agreement_attrs, _} =
      Accounts.build_user_agreement_attrs(:driver, Map.get(attrs, :agreements, []))

    vehicle_class = String.to_atom(vehicle_class)
    hiring_vehicles = Markets.list_currently_hiring_vehicles(market_id)

    user_attrs =
      attrs
      |> Map.get(:user, %{})
      |> Map.put(:agreements, agreement_attrs)

    metric_attrs =
      Map.get(attrs, :metrics, %{
        rating: 0,
        completed_matches: 0,
        rated_matches: 0,
        canceled_matches: 0,
        total_earned: 0
      })

    vehicle_class = FraytElixir.Utils.vehicle_class_atom_to_integer(vehicle_class)

    vehicle_attrs = %{vehicle_class: vehicle_class}

    attrs =
      attrs
      |> Map.put(:metrics, metric_attrs)
      |> Map.put(:user, user_attrs)
      |> Map.put(:vehicles, [vehicle_attrs])

    %Driver{}
    |> Driver.applying_changeset(attrs, hiring_vehicles)
    |> Ecto.Changeset.cast_assoc(:user, required: true)
    |> Repo.insert()
  end

  def update_current_location(driver, %Geo.Point{} = location) do
    driver
    |> Repo.preload(:current_location)
    |> Driver.current_location_changeset(location)
    |> Repo.update()
  end

  @doc """
  Updates a driver.

  ## Examples

      iex> update_driver(driver, %{field: new_value})
      {:ok, %Driver{}}

      iex> update_driver(driver, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_driver(%Driver{} = driver, attrs) do
    driver
    |> change_driver(attrs)
    |> Repo.update()
  end

  def update_driver_state(%Driver{state: from} = driver, state, notes \\ nil) do
    if from == state do
      {:error, "invalid driver state transition"}
    else
      state_transition = %DriverStateTransition{
        driver_id: driver.id,
        from: driver.state,
        to: state,
        notes: notes
      }

      driver
      |> Repo.preload(:state_transitions)
      |> Driver.update_driver_state_changeset(state_transition)
      |> Repo.update()
    end
  end

  def change_driver(%Driver{} = driver, attrs \\ %{}) do
    driver
    |> Driver.update_changeset(attrs)
    |> Ecto.Changeset.cast_assoc(:user, with: &FraytElixir.Accounts.User.update_changeset/2)
  end

  def update_driver_wallet(%Driver{} = driver, wallet_state),
    do:
      driver
      |> Driver.wallet_changeset(%{wallet_state: wallet_state})
      |> Repo.update()

  def change_vehicle(%Vehicle{} = vehicle) do
    Vehicle.admin_changeset(vehicle, %{})
  end

  def get_driver_for_user(%User{} = user) do
    query =
      from(d in Driver,
        where: d.user_id == ^user.id
      )

    driver =
      query
      |> Repo.one()
      |> Repo.preload([
        :user,
        :address,
        images: DriverDocuments.latest_driver_documents_query(),
        vehicles: [images: DriverDocuments.latest_vehicle_documents_query()]
      ])

    case driver do
      %Driver{} = driver ->
        {:ok, driver}

      _ ->
        {:error, :invalid_user, "User is not associated with a driver"}
    end
  end

  def list_available_matches_for_driver(%Driver{id: driver_id}, batch_id \\ nil) do
    filter_by_batch =
      if batch_id,
        do: dynamic([match: m], m.delivery_batch_id == ^batch_id),
        else: true

    available_matches_query(driver_id)
    |> where(^filter_by_batch)
    |> Repo.all()
    |> preload_driver_match()
  end

  defp available_matches_query(driver_id) do
    week_in_seconds = 7 * 24 * 60 * 60
    week_ago = DateTime.utc_now() |> DateTime.add(-week_in_seconds, :second)

    from(sn in SentNotification,
      as: :notification,
      join: m in assoc(sn, :match),
      as: :match,
      left_join: hidden in HiddenMatch,
      on: m.id == hidden.match_id and hidden.driver_id == ^driver_id,
      as: :hidden_match,
      where:
        sn.driver_id == ^driver_id and m.state == :assigning_driver and sn.inserted_at > ^week_ago and
          is_nil(hidden),
      where: m.preferred_driver_id == ^driver_id or m.platform == :marketplace,
      distinct: m.id,
      select: m
    )
  end

  def validate_hidden_match(driver_id, match_id) do
    qry =
      from(hidden in HiddenMatch,
        where: hidden.driver_id == ^driver_id and hidden.match_id == ^match_id
      )

    hidden_matches = Repo.all(qry)

    if Enum.count(hidden_matches) > 0, do: {:error, :forbidden}, else: :ok
  end

  def validate_hidden_customer_match(driver_id, match) do
    %{shipper_id: shipper_id} = Repo.preload(match, shipper: [:location])
    company_id = get_company_id(match)
    company_filter = if company_id, do: dynamic([h], h.company_id == ^company_id), else: true
    hidden_filter = dynamic([h], ^company_filter or h.shipper_id == ^shipper_id)

    qry =
      from(hidden in HiddenCustomer,
        where: ^hidden_filter,
        where: hidden.driver_id == ^driver_id
      )

    hidden_customers = Repo.all(qry)

    if Enum.count(hidden_customers) > 0, do: {:error, :forbidden}, else: :ok
  end

  def list_missed_matches_for_driver(driver, radius \\ 60)

  def list_missed_matches_for_driver(%Driver{current_location: %NotLoaded{}} = driver, radius),
    do:
      driver
      |> Repo.preload(:current_location)
      |> list_missed_matches_for_driver(radius)

  def list_missed_matches_for_driver(%Driver{current_location: nil}, _), do: []

  def list_missed_matches_for_driver(
        %Driver{current_location: %DriverLocation{geo_location: point}} = driver,
        radius
      ) do
    radius_in_meters = miles_to_meters(radius)

    two_days_ago =
      DateTime.utc_now()
      |> DateTime.add(-2 * 24 * 60 * 60, :second)
      |> DateTime.to_naive()

    missed_matches_in_range_query =
      from(m in Match,
        join: origin in "addresses",
        on: m.origin_address_id == origin.id,
        left_join: hidden in HiddenMatch,
        on: m.id == hidden.match_id and hidden.driver_id == ^driver.id,
        left_join: mst in MatchStateTransition,
        on: mst.match_id == m.id and mst.to == "accepted",
        where:
          st_distance_in_meters(origin.geo_location, ^point) < ^radius_in_meters and
            m.state in ^@live_match_states and is_nil(hidden.match_id) and
            m.driver_id != ^driver.id and mst.inserted_at >= ^two_days_ago,
        order_by: {:desc, mst.inserted_at}
      )

    Repo.all(missed_matches_in_range_query)
    |> preload_driver_match()
  end

  def list_live_matches_for_driver(%Driver{} = driver) do
    live_matches_query =
      from(m in Match,
        where: m.driver_id == ^driver.id and m.state in ^@live_match_states
      )

    Repo.all(live_matches_query)
    |> preload_driver_match()
  end

  def list_completed_matches_for_driver(%Driver{} = driver, page, per_page \\ 10) do
    offset = page * per_page

    result =
      from(m in Match,
        join: mst in MatchStateTransition,
        on: mst.match_id == m.id,
        where: m.driver_id == ^driver.id and mst.to in ^@completed_match_states,
        order_by: {:desc, mst.inserted_at},
        offset: ^offset,
        limit: ^per_page,
        select: %{match: m, total_matches: fragment("count(*) over ()")}
      )
      |> Repo.all()

    with true <- result |> length() > 0,
         total_matches <- result |> List.first() |> Map.get(:total_matches),
         total_pages <- div(total_matches + per_page - 1, per_page) do
      completed_matches =
        result
        |> Enum.map(&(&1.match |> preload_driver_match()))

      {:ok, %{completed_matches: completed_matches, total_pages: total_pages}}
    else
      false -> {:ok, %{completed_matches: [], total_pages: 0}}
      error -> error
    end
  end

  def filter_hidden_customers(query, :all, match) do
    filter_hidden_customers(query, :shipper, match)
    |> filter_hidden_customers(:company, match)
  end

  def filter_hidden_customers(query, :shipper, match) do
    %{shipper_id: shipper_id} = match

    case shipper_id do
      nil ->
        join(query, :left, [m], shipper in Shipper,
          as: :shipper,
          on: m.shipper_id == shipper.id
        )

      _ ->
        join(query, :left, [], shipper in Shipper,
          as: :shipper,
          on: ^shipper_id == shipper.id
        )
    end
    |> join(
      :left,
      [shipper: shipper, driver: driver],
      hidden_customer in HiddenCustomer,
      as: :hidden_customer,
      on: hidden_customer.driver_id == driver.id and shipper.id == hidden_customer.shipper_id
    )
    |> where([hidden_customer: hidden_customer], is_nil(hidden_customer))
  end

  def filter_hidden_customers(query, :company, %Match{} = match) do
    company_id = get_company_id(match)

    filter_hidden_customers(query, :company, company_id)
  end

  def filter_hidden_customers(query, :company, company_id) when is_nil(company_id), do: query

  def filter_hidden_customers(query, :company, company_id) do
    query
    |> join(:left, [driver], hidden_customer in HiddenCustomer,
      as: :hidden_company,
      on:
        hidden_customer.driver_id == driver.id and
          ^company_id == hidden_customer.company_id
    )
    |> where([hidden_company: hidden_customer], is_nil(hidden_customer))
  end

  defp get_company_id(match) do
    match = Repo.preload(match, shipper: [:location])

    get_in(match, [Access.key(:shipper, %{}), Access.key(:location, nil)])
    |> case do
      nil -> nil
      location -> location.company_id
    end
  end

  def get_driver_match(%Driver{} = driver, id) do
    Match
    |> Repo.get_by(driver_id: driver.id, id: id)
    |> Repo.preload([:origin_address, :driver, match_stops: :destination_address])
  end

  def assign_match(%Match{driver: %NotLoaded{}} = match, driver, allow_override),
    do: match |> Repo.preload(:driver) |> assign_match(driver, allow_override)

  def assign_match(%Match{driver: driver}, _driver, false) when not is_nil(driver) do
    {:error, "A driver is already assigned to this match"}
  end

  def assign_match(%Match{state: :inactive} = match, %Driver{} = driver, allow_override) do
    case Matches.update_and_authorize_match(match, %{}, match.shipper) do
      {:ok, match} -> assign_match(match, driver, allow_override)
      {:error, _type, msg, _m} -> {:error, msg}
    end
  end

  def assign_match(%Match{} = match, %Driver{} = driver, _allow_override) do
    changeset = Match.assign_driver_changeset(match, driver)

    case Repo.update(changeset) do
      {:ok, match} ->
        {:ok, final_match} =
          match
          |> Repo.preload([:driver], force: true)
          |> MatchWorkflow.accept_match()

        MatchNotifications.send_driver_assigned_sms(final_match)
        MatchNotifications.send_driver_assigned_push(final_match)

        {:ok, final_match}

      {:error, error} ->
        {:error, error}
    end
  end

  def accept_match(match, driver)

  def accept_match(_, %Driver{state: state}) when state in @disabled_states,
    do: {:error, :disabled, "Your account has been disabled"}

  def accept_match(
        %Match{platform: :deliver_pro, preferred_driver_id: expected_driver_id},
        %Driver{id: driver_id}
      )
      when expected_driver_id != driver_id do
    {:error, "This match has been reassigned"}
  end

  def accept_match(%Match{id: id}, %Driver{vehicles: vehicles} = driver) do
    with %Match{} = match <- Shipment.get_and_lock_match(id),
         match <- Repo.preload(match, [:contract, :slas]),
         :ok <- validate_hidden_match(driver.id, match.id),
         :ok <- validate_hidden_customer_match(driver.id, match),
         true <- Shipment.allowable_vehicle?(match, vehicles),
         {:ok, _} <- has_reached_accepted_match_limit?(driver),
         false <- has_reached_overlapping_matches_limit?(match, driver.id),
         {:ok, match} <-
           match
           |> Match.accept_match_changeset(driver)
           |> Repo.update() do
      match = %{match | driver: driver}

      MatchWorkflow.accept_match(match)
    else
      false -> {:error, "This match cannot be accepted by this type of vehicle"}
      true -> {:error, "This match cannot be accepted because it overlaps with another."}
      {:error, error} -> {:error, error}
    end
  end

  def toggle_en_route(%Match{state: :accepted} = match),
    do: MatchWorkflow.en_route_to_pickup(match)

  def toggle_en_route(%Match{state: :en_route_to_pickup} = match),
    do: MatchWorkflow.accept_match(match)

  def toggle_en_route(
        %MatchStop{state: :pending, match: %Match{id: match_id, state: :picked_up}} = stop
      ) do
    with %Match{match_stops: match_stops} = match <- Shipment.get_match(match_id) do
      match_stops
      |> Enum.filter(&(&1.state in MatchStopState.live_range()))
      |> Enum.each(&MatchWorkflow.pending(%{&1 | match: match}))

      {:ok, _stop} = MatchWorkflow.en_route_to_stop(stop)
      {:ok, Shipment.get_match(match_id)}
    end
  end

  def toggle_en_route(%MatchStop{state: state, match: %Match{state: :picked_up}} = stop)
      when state in [:en_route, :arrived, :signed] do
    with {:ok, _stop} <- MatchWorkflow.pending(stop) do
      {:ok, Shipment.get_match(stop.match_id)}
    end
  end

  def toggle_en_route(_match), do: {:error, :invalid_state}

  def arrived_at_pickup(%Match{} = match, parking_spot \\ "") do
    location = match.driver.current_location
    address = match.origin_address

    with :ok <- validate_parking_spot(match, parking_spot),
         :ok <- ensure_driver_is_at_address(address, location) do
      MatchWorkflow.arrive_at_pickup(match, parking_spot)
    end
  end

  def arrived_at_return(%Match{} = match, parking_spot \\ "") do
    location = match.driver.current_location
    address = match.origin_address

    with :ok <- validate_parking_spot(match, parking_spot),
         :ok <- ensure_driver_is_at_address(address, location) do
      MatchWorkflow.arrive_at_return(match, parking_spot)
    end
  end

  def picked_up(%Match{state: :arrived_at_pickup} = match, photos) do
    with {:ok, _} <-
           BarcodeReadings.barcode_reading_present_when_required?(match, :pickup),
         {:ok, match} <-
           match
           |> Match.photo_changeset(photos)
           |> Repo.update() do
      MatchWorkflow.pickup(match)
    end
  end

  def picked_up(_, _), do: {:error, :invalid_state}

  defp validate_parking_spot(%{parking_spot_required: is_required?}, parking_spot) do
    cond do
      !is_nil(parking_spot) and parking_spot != "" -> :ok
      !is_required? -> :ok
      # {:error, "Parking spot is required"}
      true -> :ok
    end
  end

  def arrived_at_stop(%MatchStop{state: :en_route, match: %Match{state: :picked_up}} = stop) do
    location = stop.match.driver.current_location
    address = stop.destination_address

    with :ok <- ensure_driver_is_at_address(address, location) do
      MatchWorkflow.arrive_at_stop(stop)
    end
  end

  def arrived_at_stop(_), do: {:error, :invalid_state}

  def sign_stop(stop, attrs, receiver_name)

  def sign_stop(
        %MatchStop{} = stop,
        %{
          "contents" => contents,
          "filename" => filename
        },
        receiver_name
      ),
      do: sign_stop(stop, %{contents: contents, filename: filename}, receiver_name)

  def sign_stop(
        %MatchStop{state: :arrived, match: %Match{state: :picked_up}} = stop,
        %{
          contents: image_contents,
          filename: image_filename
        },
        receiver_name
      ) do
    with {:ok, _} <-
           BarcodeReadings.barcode_reading_present_when_required?(stop, :delivery),
         {:ok, file} <-
           UploadHelper.file_from_base64(image_contents, image_filename, :signature_photo),
         {:ok, %MatchStop{} = stop} <-
           MatchStop.photo_changeset(stop, %{
             signature_photo: file,
             signature_name: receiver_name
           })
           |> Repo.update() do
      MatchWorkflow.sign_for_stop(stop)
    end
  end

  def sign_stop(_stop, _data, _receiver_name), do: {:error, :invalid_state}

  def undeliverable_stop(stop, reason \\ nil)

  def undeliverable_stop(%MatchStop{state: :delivered}, _),
    do: {:error, :invalid_state, "Stop has already been delivered"}

  def undeliverable_stop(%MatchStop{match: %Match{state: state}}, _)
      when state in @completed_match_states,
      do: {:error, :invalid_state, "Match has already been completed"}

  def undeliverable_stop(%MatchStop{} = stop, reason),
    do: MatchWorkflow.undeliverable_stop(stop, reason)

  def deliver_stop(%MatchStop{match: %Match{state: state}})
      when state in @completed_match_states,
      do: {:error, :invalid_state, "Match has already been delivered"}

  def deliver_stop(%MatchStop{match: %Match{state: :picked_up}, state: :signed} = stop) do
    case MatchWorkflow.deliver_stop(stop) do
      {:ok, %Match{state: :completed} = match} ->
        nps_score_id =
          if Matches.count_completed_matches_in_month(match.driver.id, :driver) == 1 do
            {:ok, nps_score} = Rating.create_nps_score(match.driver.user.id, :driver)
            nps_score.id
          end

        {:ok, match, nps_score_id}

      {:ok, match} ->
        {:ok, match, nil}
    end
  end

  def deliver_stop(%MatchStop{match: %Match{}}),
    do: {:error, :invalid_state, "Match must be signed before it can be delivered"}

  def deliver_stop(
        %MatchStop{} = stop,
        %{
          "contents" => image_contents,
          "filename" => image_filename
        }
      ) do
    with {:ok, file} <-
           UploadHelper.file_from_base64(image_contents, image_filename, :destination_photo),
         {:ok, %MatchStop{} = stop} <-
           MatchStop.photo_changeset(stop, %{destination_photo: file}) |> Repo.update() do
      deliver_stop(stop)
    end
  end

  def deliver_stop(%MatchStop{} = stop, nil),
    do: deliver_stop(stop)

  defp ensure_driver_is_at_address(_address, nil),
    do:
      {:error,
       "Your current location is not showing at the current address. Please restart your app if you feel this is incorrect. Contact the Frayt support team if the problem continues."}

  defp ensure_driver_is_at_address(address, %DriverLocation{geo_location: driver_point}) do
    distance = Geocalc.distance_between(address.geo_location, driver_point)

    if distance <= 500 do
      :ok
    else
      ensure_driver_is_at_address(address, nil)
    end
  end

  def cancel_match(%Match{} = match, reason) do
    with {:ok, updated_match} <- MatchWorkflow.driver_cancel_match(match, reason),
         {:ok, _} <- create_driver_cancellation(match, reason) do
      {:ok, updated_match}
    else
      {:error, msg} -> {:error, msg}
      _ -> {:error, "something went wrong"}
    end
  end

  def unable_to_pickup_match(%Match{} = match, reason, driver_location \\ nil) do
    MatchWorkflow.unable_to_pickup_match(match, reason, driver_location)
  end

  def reject_match(
        %Match{id: match_id, platform: platform} = match,
        %Driver{id: driver_id}
      ) do
    with {:ok, %HiddenMatch{} = hidden_match} <-
           %HiddenMatch{type: "driver_rejected"}
           |> HiddenMatch.changeset(%{match_id: match_id, driver_id: driver_id})
           |> Ecto.Changeset.cast_assoc(:driver)
           |> Ecto.Changeset.cast_assoc(:match)
           |> Repo.insert(),
         %HiddenMatch{driver: driver} <- hidden_match |> Repo.preload(:driver) do
      if platform === :deliver_pro,
        do:
          MatchNotifications.send_notifications(
            match,
            driver
          )

      {:ok, hidden_match}
    end
  end

  def create_driver_cancellation(%Match{id: match_id, driver_id: driver_id}, reason) do
    HiddenMatch.changeset(%HiddenMatch{}, %{
      type: "driver_cancellation",
      reason: reason,
      match_id: match_id,
      driver_id: driver_id
    })
    |> Repo.insert()
  end

  def create_driver_removal(%{match_id: match_id, driver_id: driver_id}) do
    HiddenMatch.changeset(%HiddenMatch{}, %{
      reason: nil,
      type: "driver_removed",
      match_id: match_id,
      driver_id: driver_id
    })
    |> Repo.insert()
  end

  def set_initial_password(%User{} = user, password, password_confirmation) do
    user
    |> User.set_initial_password_changeset(%{
      password: password,
      password_confirmation: password_confirmation
    })
    |> Repo.update()
  end

  def change_password(%User{} = user, %{
        current: current_password,
        new: password,
        confirmation: password_confirmation
      }) do
    case Accounts.check_password(user, current_password) do
      {:ok, %User{} = user} ->
        user
        |> User.change_password_changeset(%{
          password: password,
          password_confirmation: password_confirmation
        })
        |> Repo.update()

      {:error, :invalid_credentials} ->
        {:error, :invalid_credentials, "Password is incorrect"}

      e ->
        e
    end
  end

  def update_driver_identity(driver, params) do
    driver
    |> Driver.identity_changeset(params)
    |> Repo.update()
  end

  def update_driver_metrics(%Driver{id: driver_id}) do
    case update_all_driver_metrics(driver_id: driver_id, returning: true) do
      {:error, _message} = e -> e
      {:ok, 1, [metrics]} -> {:ok, metrics}
      {:ok, _, _} -> {:ok, []}
    end
  end

  def update_all_driver_metrics(opts \\ []) do
    {count, returned} = update_all_driver_metrics!(opts)
    {:ok, count, returned}
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  def update_all_driver_metrics!(opts \\ []) do
    {driver_id, opts} = Keyword.pop(opts, :driver_id)
    query = DriverMetrics.calculate_metrics_query(driver_id)

    Repo.insert_all(
      DriverMetrics,
      query,
      [
        conflict_target: [:driver_id],
        on_conflict: {:replace_all_except, [:id, :driver_id, :inserted_at]}
      ] ++
        opts
    )
  end

  def get_driver_email(%Driver{user: %Ecto.Association.NotLoaded{}} = driver),
    do: driver |> Repo.preload(:user) |> get_driver_email()

  def get_driver_email(%Driver{user: %User{email: email}}), do: email
  def get_driver_email(_), do: nil

  def get_current_location(%Driver{current_location: %NotLoaded{}} = driver),
    do:
      driver
      |> Repo.preload(:current_location)
      |> get_current_location()

  def get_current_location(%Driver{current_location: %DriverLocation{} = current_location}),
    do: current_location

  def get_current_location(driver_id) when is_binary(driver_id),
    do: get_driver!(driver_id) |> get_current_location()

  def get_current_location(_), do: nil

  def disable_driver_account(%Driver{} = driver, notes) do
    %{first_name: first_name, last_name: last_name, user: %User{email: email}} = driver

    case update_driver_state(driver, :disabled, notes) do
      {:ok, driver} ->
        Email.disable_driver_account_email(%{
          email: email,
          note: notes,
          first_name: first_name,
          last_name: last_name
        })
        |> Mailer.deliver_later()

        {:ok, driver}

      _ ->
        :error
    end
  end

  def reactivate_driver(%Driver{} = driver) do
    case update_driver_state(driver, :approved) do
      {:ok, driver} ->
        driver
        |> Map.take([:first_name, :last_name])
        |> Map.put(:email, driver.user.email)
        |> Email.reactivate_driver_account_email()
        |> Mailer.deliver_later()

        {:ok, driver}

      _ ->
        :error
    end
  end

  def get_max_volume(driver) do
    driver
    |> get_max_vehicle_class()
    |> VehicleClass.get_attribute(:max_volume)
  end

  def get_max_vehicle_class(%Driver{vehicles: %NotLoaded{}} = driver),
    do: driver |> Repo.preload(:vehicles) |> get_max_vehicle_class()

  def get_max_vehicle_class(%Driver{vehicles: vehicles}) do
    vehicles
    |> Enum.map(& &1.vehicle_class)
    |> Enum.max()
  end

  defp preload_driver_match(match) do
    match
    |> Repo.preload([
      :origin_address,
      :shipper,
      :state_transitions,
      :sender,
      driver: [:user],
      match_stops: [:destination_address, :items, :recipient]
    ])
  end

  defp has_reached_overlapping_matches_limit?(%Match{contract: nil}, _driver_id), do: false

  defp has_reached_overlapping_matches_limit?(match, driver_id) do
    %{
      slas: accepting_match_slas,
      contract: %{
        active_match_factor: active_match_factor,
        active_matches: active_matches_allowed,
        active_match_duration: duration
      }
    } = match

    accepting_match_sla = get_sla_by_type(accepting_match_slas, :pickup)

    active_matches =
      case active_match_factor do
        :delivery_duration ->
          from([_m, slas] in get_active_matches_slas_qry(driver_id),
            where: slas.type in [:delivery],
            where: slas.start_time <= ^accepting_match_sla.start_time,
            where: slas.end_time >= ^accepting_match_sla.start_time
          )

        _ ->
          from([_m, slas] in get_active_matches_slas_qry(driver_id),
            where: slas.type in [:pickup],
            where: slas.start_time <= ^accepting_match_sla.start_time,
            where:
              datetime_add(slas.start_time, ^duration, "minute") >=
                ^accepting_match_sla.start_time
          )
      end
      |> Repo.all()

    length(active_matches) != 0 and length(active_matches) >= active_matches_allowed
  end

  defp get_sla_by_type(slas, type) do
    Enum.find(slas, nil, &(&1.type == type))
  end

  defp get_active_matches_slas_qry(driver_id) do
    from(m in active_matches_qry(driver_id),
      left_join: slas in assoc(m, :slas),
      preload: [slas: slas]
    )
  end

  defp has_reached_accepted_match_limit?(%Driver{
         id: driver_id,
         active_match_limit: active_match_limit
       }) do
    accepted_matches = active_matches_count(driver_id)

    active_match_limit =
      if is_nil(active_match_limit), do: @accepted_match_limit, else: active_match_limit

    if accepted_matches >= active_match_limit,
      do:
        {:error,
         "You can not have more than #{active_match_limit} ongoing matches. Please complete your current matches, or contact a Network Operator to be assigned more."},
      else: {:ok, "has not reached match limit"}
  end

  def hide_customer_matches(driver, customer, reason \\ nil)

  def hide_customer_matches(%Driver{id: driver_id}, %Company{id: company_id}, reason),
    do: create_hidden_customer(%{driver_id: driver_id, company_id: company_id, reason: reason})

  def hide_customer_matches(%Driver{id: driver_id}, %Shipper{id: shipper_id}, reason),
    do: create_hidden_customer(%{driver_id: driver_id, shipper_id: shipper_id, reason: reason})

  def delete_hidden_customer(id) do
    case Repo.get(HiddenCustomer, id) do
      %HiddenCustomer{} = hidden_customer -> Repo.delete(hidden_customer)
      nil -> {:error, :not_found}
    end
  end

  defp create_hidden_customer(attrs),
    do:
      %HiddenCustomer{}
      |> HiddenCustomer.changeset(attrs)
      |> Repo.insert()

  def complete_driver_application(%Driver{} = driver) do
    driver
    |> Driver.complete_driver_changeset(%{state: :pending_approval})
    |> Repo.update()
  end

  def list_background_checks(driver_id) do
    qry =
      from(b in BackgroundCheck,
        where: b.driver_id == ^driver_id
      )

    Repo.all(qry)
  end

  def get_locations_for_match(%Match{driver_id: nil}), do: []

  def get_locations_for_match(%Match{driver_id: driver_id} = match) do
    from = Shipment.match_transitioned_at(match, :en_route_to_pickup, :desc)

    if from do
      to = Shipment.match_transitioned_at(match, [:completed, :canceled, :admin_canceled], :desc)

      to =
        cond do
          is_nil(to) -> NaiveDateTime.utc_now()
          NaiveDateTime.compare(from, to) == :gt -> NaiveDateTime.utc_now()
          true -> to
        end

      DriverLocation
      |> where([dl], dl.driver_id == ^driver_id)
      |> where([dl], dl.inserted_at >= ^from and dl.inserted_at <= ^to)
      |> order_by([dl], asc: dl.inserted_at)
      |> Repo.all()
    else
      []
    end
  end
end

defimpl FraytElixir.RecordSearch, for: FraytElixir.Drivers.Driver do
  alias FraytElixir.{Repo, Drivers}
  alias Drivers.Driver
  @preload [:user]

  def display_record(d),
    do: "#{d.first_name} #{d.last_name} (#{d.user.email})"

  def list_records(_record, filters),
    do:
      %{
        per_page: 4,
        order_by: :last_name,
        order: :asc
      }
      |> Map.merge(filters)
      |> Drivers.list_drivers(@preload)

  def get_record(%{id: id}), do: Repo.get(Driver, id) |> Repo.preload(@preload)
end
