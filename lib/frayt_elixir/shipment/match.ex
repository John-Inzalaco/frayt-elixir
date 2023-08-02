defmodule FraytElixir.Shipment.Match do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema
  require Logger
  import Ecto.Query, only: [from: 2]
  import FraytElixir.QueryHelpers, only: [between?: 3]
  import FraytElixir.Guards

  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.MatchUnloadMethod
  alias FraytElixir.{Photo, Repo}
  alias Ecto.Changeset
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Markets
  alias FraytElixir.Markets.Market

  alias FraytElixir.Shipment.{
    Address,
    DeliveryBatch,
    HiddenMatch,
    ShipperMatchCoupon,
    MatchStateTransition,
    MatchStop,
    MatchState,
    MatchTag,
    MatchFee,
    Contact,
    ETA
  }

  alias FraytElixir.SLAs
  alias FraytElixir.SLAs.MatchSLA

  alias FraytElixir.Contracts.Contract

  alias FraytElixir.Accounts.{AdminUser, Schedule, Shipper, Location}
  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Notifications.NotificationBatch

  @completed_states MatchState.completed_range()
  @active_states MatchState.active_range()
  @visible_states MatchState.visible_range()
  @canceled_states MatchState.canceled_range()
  @scheduled_states MatchState.scheduled_range()
  @inactive_states MatchState.inactive_range()
  @all_states MatchState.all_range()
  @forbidden_update_fields [:service_level, :vehicle_class, :unload_method]

  schema "matches" do
    field :shortcode, :string
    field :expected_toll, :integer, default: 0
    field :amount_charged, :integer
    field :driver_total_pay, :integer
    field :driver_fees, :integer
    field :price_discount, :integer, default: 0
    field :vehicle_class, :integer
    field :service_level, :integer
    field :total_distance, :float
    field :markup, :float, default: 1.0
    field :scheduled, :boolean
    field :manual_price, :boolean, default: false
    field :pickup_at, :utc_datetime
    field :dropoff_at, :utc_datetime
    field :authorized_at, :utc_datetime, virtual: true
    field :pickup_notes, :string
    field :admin_notes, :string
    field :identifier, :string
    field :po, :string
    field :state, MatchState.Type, default: :pending
    field :origin_photo, Photo.Type
    field :bill_of_lading_photo, Photo.Type
    field :bill_of_lading_required, :boolean
    field :driver_cut, :float, default: 0.75
    field :total_weight, :integer
    field :total_volume, :integer
    field :travel_duration, :integer, default: 0
    field :unload_method, MatchUnloadMethod.Type
    field :self_sender, :boolean, default: true

    field :slack_thread_id, :string
    field :cancel_charge, :integer
    field :cancel_charge_driver_pay, :integer
    field :cancel_reason, :string
    field :origin_photo_required, :boolean
    field :rating, :integer
    field :rating_reason, :string
    field :timezone, :string
    field :optimized_stops, :boolean, default: false
    field :lock_version, :integer, default: 1
    field :platform, Ecto.Enum, values: [:marketplace, :deliver_pro]
    field :parking_spot_required, :boolean, default: false

    field :meta, :map, default: %{}

    belongs_to :contract, Contract, on_replace: :nilify
    belongs_to :sender, Contact, on_replace: :update
    belongs_to :shipper, Shipper, on_replace: :nilify
    belongs_to :driver, Driver
    belongs_to :origin_address, Address, on_replace: :nilify
    belongs_to :network_operator, AdminUser
    belongs_to :schedule, Schedule
    belongs_to :delivery_batch, DeliveryBatch
    belongs_to :market, Market, on_replace: :nilify
    belongs_to :preferred_driver, Driver
    has_one :shipper_match_coupon, ShipperMatchCoupon, on_replace: :delete
    has_one :coupon, through: [:shipper_match_coupon, :coupon]
    has_one :eta, ETA
    has_many :notification_batches, NotificationBatch
    has_many :fees, MatchFee, on_replace: :delete
    has_many :slas, MatchSLA, on_replace: :delete
    has_many :hidden_matches, HiddenMatch
    has_many :payment_transactions, PaymentTransaction
    has_many :state_transitions, MatchStateTransition
    has_many :match_stops, MatchStop, on_replace: :delete
    has_many :tags, MatchTag, on_replace: :delete

    timestamps()
  end

  def excluding_pending(query) do
    from(m in query,
      where: m.state != "pending"
    )
  end

  def where_shipper_is(query, shipper_id) do
    from(m in query,
      where: m.shipper_id == type(^shipper_id, :binary_id)
    )
  end

  def where_location_is(query, location_id) do
    from(m in query,
      join: s in assoc(m, :shipper),
      where: s.location_id == type(^location_id, :binary_id)
    )
  end

  def where_company_is(query, company_id) do
    from(m in query,
      join: s in assoc(m, :shipper),
      join: l in assoc(s, :location),
      where: l.company_id == type(^company_id, :binary_id)
    )
  end

  def filter_by_permissions(
        query,
        %Shipper{location_id: nil, id: shipper_id},
        _location_id,
        _shipper_id
      ),
      do: where_shipper_is(query, shipper_id)

  def filter_by_permissions(
        query,
        %Shipper{role: :company_admin} = shipper,
        location_id,
        shipper_id
      ) do
    shipper = Repo.preload(shipper, :location)

    query =
      cond do
        not is_nil(shipper_id) -> where_shipper_is(query, shipper_id)
        not is_nil(location_id) -> where_location_is(query, location_id)
        true -> query
      end

    where_company_is(query, shipper.location.company_id)
  end

  def filter_by_permissions(
        query,
        %Shipper{location_id: location_id},
        _location_id,
        shipper_id
      ) do
    query =
      if is_nil(shipper_id) do
        query
      else
        where_shipper_is(query, shipper_id)
      end

    where_location_is(query, location_id)
  end

  def filter_by_company(query, nil), do: query

  def filter_by_company(query, company_id),
    do:
      from(m in query,
        left_join: s in assoc(m, :shipper),
        left_join: l in assoc(s, :location),
        where: l.company_id == ^company_id
      )

  def filter_by_contract(query, nil), do: query

  def filter_by_contract(query, contract_id),
    do: from(m in query, where: m.contract_id == ^contract_id)

  def filter_by_shipper(query, nil), do: query

  def filter_by_shipper(query, shipper_id),
    do: from(m in query, where: m.shipper_id == ^shipper_id)

  def filter_by_driver(query, nil), do: query

  def filter_by_driver(query, driver_id),
    do: from(m in query, where: m.driver_id == ^driver_id)

  def filter_by_vehicle_type(query, nil), do: query

  def filter_by_vehicle_type(query, vehicle_type) when is_number(vehicle_type),
    do: filter_by_vehicle_type(query, [vehicle_type])

  def filter_by_vehicle_type(query, vehicle_type) when length(vehicle_type) in [0, 4], do: query

  def filter_by_vehicle_type(query, vehicle_type) do
    from(m in query,
      where: m.vehicle_class in ^vehicle_type
    )
  end

  def filter_by_stops(query, nil), do: query

  def filter_by_stops(query, :single),
    do:
      from(m in query,
        left_join:
          msc in subquery(
            from(
              ms in MatchStop,
              group_by: ms.match_id,
              select: %{match_id: ms.match_id, count: count(ms.id)}
            )
          ),
        on: msc.match_id == m.id,
        where: msc.count <= 1
      )

  def filter_by_stops(query, :multi),
    do:
      from(m in query,
        left_join:
          msc in subquery(
            from(
              ms in MatchStop,
              group_by: ms.match_id,
              select: %{match_id: ms.match_id, count: count(ms.id)}
            )
          ),
        on: msc.match_id == m.id,
        where: msc.count > 1
      )

  def filter_by_dates(query, start_date, end_date)
      when is_empty(start_date) and is_empty(end_date),
      do: query

  def filter_by_dates(query, start_date, end_date) do
    from(m in query,
      join: mst in subquery(authorized_time_query()),
      on: m.id == mst.match_id,
      where:
        (m.scheduled and between?(m.pickup_at, ^start_date, ^end_date)) or
          (not m.scheduled and
             ((is_nil(mst.inserted_at) and between?(m.inserted_at, ^start_date, ^end_date)) or
                (not is_nil(mst.inserted_at) and between?(mst.inserted_at, ^start_date, ^end_date))))
    )
  end

  defp authorized_time_query do
    from(
      mst in MatchStateTransition,
      where: mst.to == "assigning_driver",
      select: %{match_id: mst.match_id, inserted_at: min(mst.inserted_at)},
      group_by: mst.match_id
    )
  end

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(m in query,
        left_join: o in assoc(m, :origin_address),
        where:
          ilike(fragment("CONCAT('#', ?)", m.id), ^"%#{search_query}%") or
            ilike(fragment("CONCAT('#', ?)", m.shortcode), ^"%#{search_query}%") or
            ilike(fragment("CONCAT(?, ', ', ?)", o.city, o.state), ^"%#{search_query}%") or
            ilike(m.identifier, ^"%#{search_query}%") or ilike(m.po, ^"%#{search_query}%") or
            ilike(m.pickup_notes, ^"%#{search_query}%")
      )

  def filter_by_state(query, :active),
    do:
      from(m in query,
        where: m.state in ^@active_states
      )

  def filter_by_state(query, :complete),
    do:
      from(m in query,
        where: m.state in ^@completed_states
      )

  def filter_by_state(query, :canceled),
    do:
      from(m in query,
        where: m.state in ^@canceled_states
      )

  def filter_by_state(query, :scheduled),
    do:
      from(m in query,
        where: m.state in ^@scheduled_states
      )

  def filter_by_state(query, :inactive),
    do:
      from(m in query,
        where: m.state in ^@inactive_states
      )

  def filter_by_state(query, :assigning_driver),
    do:
      from(m in query,
        where: m.state == "assigning_driver"
      )

  def filter_by_state(query, :all),
    do:
      from(m in query,
        where: m.state in ^@all_states
      )

  def filter_by_state(query, :unable_to_pickup),
    do:
      from(m in query,
        where: m.state == :unable_to_pickup
      )

  def filter_by_state(query, _),
    do:
      from(m in query,
        where: m.state in ^@visible_states
      )

  def filter_by_sla(query, :caution) do
    current_time = DateTime.utc_now()

    from(m in query,
      join:
        csla in subquery(
          from(sla in MatchSLA,
            join: m0 in __MODULE__,
            on: m0.id == sla.match_id,
            where:
              (sla.type == :acceptance and m0.state == :assigning_driver) or
                (sla.type == :pickup and
                   m0.state in [:accepted, :en_route_to_pickup, :arrived_at_pickup]) or
                (sla.type == :delivery and m0.state == :picked_up),
            where: sla.end_time <= datetime_add(^current_time, 15, "minute"),
            group_by: sla.match_id,
            select: %{match_id: sla.match_id}
          )
        ),
      on: m.id == csla.match_id
    )
  end

  def filter_by_sla(query, _), do: query

  def filter_by_transaction_type(query, :captures),
    do: filter_by_transaction_type(query, "capture")

  def filter_by_transaction_type(query, :transfers),
    do: filter_by_transaction_type(query, "transfer")

  def filter_by_transaction_type(query, :all), do: query

  def filter_by_transaction_type(query, :failed),
    do:
      from(m in query,
        as: :matches,
        inner_lateral_join:
          p in subquery(
            from(
              p in PaymentTransaction,
              order_by: [desc: p.inserted_at],
              where:
                p.transaction_type in ["capture", "transfer"] and
                  parent_as(:matches).id == p.match_id,
              limit: 1
            )
          ),
        on: m.id == p.match_id,
        where: p.status == "error"
      )

  def filter_by_transaction_type(query, type) when type in ["capture", "transfer"],
    do:
      from(m in query,
        as: :matches,
        inner_lateral_join:
          p in subquery(
            from(
              p in PaymentTransaction,
              order_by: [desc: p.inserted_at],
              where: p.transaction_type == ^type and parent_as(:matches).id == p.match_id,
              limit: 1
            )
          ),
        on: m.id == p.match_id,
        where: p.status == "error"
      )

  def filter_by_transaction_type(query, _), do: query

  def filter_by_network_operator(query, admin_user_id) when is_binary(admin_user_id),
    do:
      from(m in query,
        where: m.network_operator_id == ^admin_user_id
      )

  def filter_by_network_operator(query, _), do: query

  def calculate_match_payment_totals(query, id) do
    from(m in query,
      join: p in assoc(m, :payment_transactions),
      where: p.status == "succeeded" and m.id == ^id,
      select: %{
        total_charged:
          sum(
            fragment(
              "coalesce(CASE WHEN ? = 'capture' THEN ? END, 0)",
              p.transaction_type,
              p.amount
            )
          ),
        total_refunded:
          sum(
            fragment(
              "coalesce(CASE WHEN ? = 'refund' THEN ? END, 0)",
              p.transaction_type,
              p.amount
            )
          ),
        driver_paid:
          sum(
            fragment(
              "coalesce(CASE WHEN ? = 'transfer' THEN ? END, 0)",
              p.transaction_type,
              p.amount
            )
          )
      }
    )
  end

  @allowed_fields ~w(pickup_at dropoff_at
    pickup_notes po admin_notes state shortcode identifier origin_photo_required
    shipper_id manual_price network_operator_id schedule_id scheduled timezone
    service_level unload_method vehicle_class self_sender optimized_stops
    sender_id contract_id bill_of_lading_required meta preferred_driver_id platform
    parking_spot_required
  )a

  @int_max 2_147_483_647

  @doc false
  def changeset(match, attrs) do
    match
    |> cast(attrs, @allowed_fields)
    |> assoc_stops()
    |> assoc_when(:sender, [{:self_sender, :equal_to, false}], required: true)
    |> cast_assoc(:fees)
    |> Address.assoc_address(match, :origin_address)
    |> validate_length(:cancel_reason, max: 500)
    |> validate_number(:total_weight, less_than: @int_max)
    |> validate_number(:total_volume, less_than: @int_max)
    |> validate_number(:vehicle_class,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 4,
      message: "does not exist; choose another vehicle class"
    )
    |> validate_estimate()
    |> validate_box_truck()
    |> validate_preferred_driver_update()
    |> validate_platform_change()
  end

  def override_changeset(match, attrs) do
    changeset = cast(match, attrs, [])

    stop_cs = {MatchStop, :override_changeset, [apply_changes(changeset)]}

    changeset
    |> cast_assoc(:match_stops, with: stop_cs)
  end

  def coupon_changeset(match, attrs) do
    match
    |> cast(attrs, [])
    |> cast_assoc(:shipper_match_coupon, with: &ShipperMatchCoupon.changeset(&1, &2, match))
  end

  def cancel_charge_changeset(match, attrs) do
    match
    |> cast(attrs, [:cancel_charge, :cancel_charge_driver_pay])
    |> validate_required([:cancel_charge])
    |> validate_number(:cancel_charge, greater_than_or_equal_to: 0)
    |> validate_number(:cancel_charge_driver_pay, greater_than_or_equal_to: 0)
  end

  def validation_changeset(match) do
    attrs = %{
      match_stops:
        Enum.map(match.match_stops, fn stop ->
          %{id: stop.id, items: Enum.map(stop.items, fn item -> %{id: item.id} end)}
        end)
    }

    changeset = cast(match, attrs, [])

    stop_cs = {MatchStop, :validation_changeset, [apply_changes(changeset)]}

    changeset
    |> cast_assoc(:match_stops, with: stop_cs)
    |> validate_required([
      :origin_address_id,
      :shipper_id
    ])
    |> validate_shipper_approved()
    |> validate_estimate()
  end

  def payout_changeset(match, attrs) do
    match
    |> cast(attrs, [
      :amount_charged,
      :driver_total_pay,
      :price_discount
    ])
    |> optimistic_lock(:lock_version)
    |> validate_payout()
  end

  @allowed_metric_cs ~w(total_volume total_weight total_distance travel_duration unload_method
    expected_toll vehicle_class markup service_level timezone optimized_stops)a

  def metrics_changeset(match, attrs) do
    market = Map.get(attrs, :market)

    match
    |> cast(attrs, @allowed_metric_cs)
    |> cast_assoc(:match_stops, with: &MatchStop.metrics_changeset/2)
    |> put_assoc(:market, market)
    |> validate_index()
    |> validate_number(:vehicle_class,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 4,
      message: "does not exist; choose another vehicle class"
    )
    |> validate_number(:service_level,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 2,
      message: "does not exist; choose another service level"
    )
    |> validate_number(:markup, greater_than: 0)
    |> validate_number(:expected_toll, greater_than_or_equal_to: 0)
    |> validate_metrics()
    |> validate_box_truck()
  end

  defp validate_index(changeset) do
    match_stops_idx =
      get_field(changeset, :match_stops)
      |> Enum.map(&Map.get(&1, :index))
      |> Enum.sort()

    start = List.first(match_stops_idx)

    must_index = Enum.to_list(start..(length(match_stops_idx) + start - 1))

    valid_match_stops_indexes? = match_stops_idx -- must_index == []

    validate_change(changeset, :match_stops, fn :match_stops, _ ->
      if valid_match_stops_indexes? do
        []
      else
        [match_stops: "Match stop indexes are invalid."]
      end
    end)
  end

  def pricing_changeset(match, attrs) do
    match
    |> cast(attrs, [
      :driver_cut,
      :driver_fees,
      :expected_toll
    ])
    |> cast_assoc(:match_stops, with: &MatchStop.price_changeset/2)
    |> cast_assoc(:fees)
    |> validate_pricing()
  end

  def photo_changeset(match, attrs) do
    match
    |> cast_attachments(attrs, [:origin_photo, :bill_of_lading_photo])
  end

  def delivery_batch_changeset(
        match,
        %{match_stops: match_stops, origin_address: origin_address} = attrs
      ) do
    match
    |> cast(attrs, [
      :state,
      :shipper_id,
      :po,
      :vehicle_class,
      :service_level,
      :total_distance,
      :schedule_id,
      :pickup_at,
      :scheduled,
      :delivery_batch_id,
      :manual_price,
      :timezone,
      :unload_method
    ])
    |> put_assoc(:origin_address, origin_address)
    |> put_assoc(:match_stops, match_stops)
  end

  def manual_pricing_changeset(match, attrs) do
    match
    |> cast(attrs, [:manual_price])
    |> cast_assoc(:fees)
    |> validate_required([:manual_price])
  end

  def state_changeset(match, attrs) do
    match
    |> cast(attrs, [:state])
    |> validate_required([:state])
    |> optimistic_lock(:lock_version)
  end

  def slack_thread_changeset(match, attrs) do
    match
    |> cast(attrs, [:slack_thread_id])
  end

  def assign_driver_changeset(match, driver) do
    allowed_states = MatchState.active_range() ++ MatchState.inactive_range()

    match
    |> cast(%{driver_id: driver.id}, [:driver_id])
    |> optimistic_lock(:lock_version)
    |> validate_required([:driver_id])
    |> validate_current_state_is(allowed_states)
    |> validate_driver(driver)
  end

  def accept_match_changeset(match, driver) do
    match
    |> assign_driver_changeset(driver)
    |> validate_current_state_is([:assigning_driver, :scheduled])
  end

  def remove_driver_changeset(match) do
    attrs = %{driver_id: nil}

    match
    |> cast(attrs, [:driver_id])
  end

  def rate_driver_changeset(match, attrs) do
    match
    |> cast(attrs, [:rating, :rating_reason])
    |> validate_number(:rating, less_than_or_equal_to: 5)
    |> validate_number(:rating, greater_than_or_equal_to: 0)
  end

  def api_update_changeset(match, attrs) do
    changeset =
      match
      |> cast(attrs, @forbidden_update_fields)
      |> valid_fields()

    changeset
    |> cast_assoc(:match_stops, with: &MatchStop.api_update_changeset/2)
  end

  defp assoc_stops(%Changeset{params: attrs} = changeset) do
    case attrs do
      %{"match_stops" => [%MatchStop{} | _] = stops} ->
        changeset |> put_assoc(:match_stops, stops)

      _ ->
        changeset |> cast_assoc(:match_stops)
    end
  end

  defp validate_estimate(changeset) do
    changeset
    |> validate_required([:state, :shortcode, :self_sender])
    |> validate_assoc_length(:match_stops, min: 1, max: 60)
    |> validate_max_declared_value()
  end

  defp validate_shipper_approved(changeset) do
    shipper = Map.get(changeset.data, :shipper, nil)

    case shipper do
      %Shipper{state: :approved} -> changeset
      _ -> add_error(changeset, :shipper, "Your account is still pending approval.")
    end
  end

  defp validate_max_declared_value(changeset) do
    validate_change(changeset, :match_stops, fn :match_stops, stops ->
      total_declared_value = sum_total_declared_value(stops)

      ## TODO: Create a config table in order to set internal values
      ## Frayt_Address, telephone, max insure coverage, and so...
      if total_declared_value > 10_000_00 do
        [
          {:match_stops,
           "We can insure up to $10,000. If you need additional coverage contact our sales team."}
        ]
      else
        []
      end
    end)
  end

  defp sum_total_declared_value(stops) do
    Enum.reduce(stops, 0, fn stop, acc ->
      items = get_field(stop, :items, [])

      total_declared_by_stop =
        Enum.reduce(items, 0, fn item, accx ->
          accx + (item.declared_value || 0)
        end)

      acc + total_declared_by_stop
    end)
  end

  defp validate_payout(changeset),
    do:
      changeset
      |> validate_required([
        :amount_charged,
        :driver_total_pay,
        :price_discount
      ])

  defp validate_metrics(changeset) do
    changeset
    |> validate_required([
      :total_volume,
      :total_weight,
      :total_distance,
      :expected_toll,
      :vehicle_class,
      :markup,
      :service_level
    ])
    |> validate_market()
    |> validate_same_day()
    |> validate_date_time(:dropoff_at, greater_than_or_equal_to: get_field(changeset, :pickup_at))
    |> validate_date_time(:pickup_at, less_than_or_equal_to: get_field(changeset, :dropoff_at))
    |> validate_required([:scheduled])
    |> validate_required_when(:pickup_at, [{:scheduled, :equal_to, true}])
    |> validate_for_shipper(fn changeset ->
      changeset
      |> SLAs.validate_sla_scheduling()
      |> validate_operational_date()
      |> validate_credit_card_scheduled_cutoff()
    end)
  end

  defp validate_operational_date(changeset) do
    changeset
    |> validate_scheduling(fn changeset, field, date_time ->
      if should_skip_validation?(changeset, date_time) do
        changeset
      else
        validate_holidays(changeset, field, date_time)
      end
    end)
  end

  # Skip validation for tests if validating the current day. This prevents tests failing on holidays and weekends
  defp should_skip_validation?(changeset, date_time) do
    env = Application.get_env(:frayt_elixir, :environment)
    timezone = get_field(changeset, :timezone)
    current_time = DateTime.utc_now() |> DisplayFunctions.datetime_with_timezone(timezone)

    cond do
      env != :test -> false
      NaiveDateTime.to_date(date_time) == NaiveDateTime.to_date(current_time) -> true
      true -> false
    end
  end

  defp validate_scheduling(changeset, validator) do
    case get_field(changeset, :scheduled) do
      true ->
        changeset
        |> validate_scheduling(:pickup_at, validator)
        |> validate_scheduling(:dropoff_at, validator)

      _ ->
        validate_scheduling(changeset, :inserted_at, validator)
    end
  end

  defp validate_scheduling(changeset, :inserted_at, validator) do
    date = get_authorized_time(changeset)
    validate_scheduling(changeset, :inserted_at, date, validator)
  end

  defp validate_scheduling(changeset, field, validator) do
    date = get_field(changeset, field)
    validate_scheduling(changeset, field, date, validator)
  end

  defp validate_scheduling(changeset, _field, nil, _validator), do: changeset

  defp validate_scheduling(changeset, field, date_time, validator) do
    timezone = get_field(changeset, :timezone)
    date_time = DisplayFunctions.datetime_with_timezone(date_time, timezone)
    current_time = DateTime.utc_now() |> DisplayFunctions.datetime_with_timezone(timezone)
    env = Application.get_env(:frayt_elixir, :environment)

    date = NaiveDateTime.to_date(date_time)
    current_date = NaiveDateTime.to_date(current_time)

    if env == :test and date == current_date do
      changeset
    else
      validator.(changeset, field, date_time)
    end
  end

  @full_holidays ["Christmas Day"]

  defp validate_holidays(changeset, field, date_time) do
    holiday = get_holiday(date_time)

    error =
      if holiday in @full_holidays do
        "cannot be on %{holiday}"
      end

    if error do
      Changeset.add_error(changeset, field, error,
        validation: :not_a_holiday,
        holiday: holiday
      )
    else
      changeset
    end
  end

  defp get_holiday(date_time) do
    date = NaiveDateTime.to_date(date_time)

    with {:ok, holidays} <- Holidefs.on(:fed, date),
         %Holidefs.Holiday{name: name} <-
           Enum.find(holidays, &(&1.name in @full_holidays)) do
      name
    else
      _ -> nil
    end
  end

  defp validate_box_truck(changeset) do
    case get_field(changeset, :vehicle_class) do
      4 ->
        changeset
        |> cast(%{bill_of_lading_required: true}, [:bill_of_lading_required])
        |> validate_required([:unload_method])
        |> validate_required_when(:pickup_at, [{:scheduled, :equal_to, true}])

      nil ->
        changeset

      _ ->
        validate_truckless_unload_method(changeset)
    end
  end

  defp validate_credit_card_scheduled_cutoff(changeset) do
    shipper = changeset.data.shipper
    shipper = shipper |> Repo.preload(location: [:company])

    with %Shipper{location: %Location{company: company}} <- shipper,
         false <- company.account_billing_enabled do
      cutoff_time = DateTime.add(DateTime.utc_now(), 604_800, :second)
      validate_date_time(changeset, :pickup_at, less_than: cutoff_time)
    else
      _ -> changeset
    end
  end

  defp validate_truckless_unload_method(changeset) do
    validate_change(changeset, :unload_method, fn _field, unload_method ->
      case unload_method do
        unload_method when unload_method in [:dock_to_dock, :lift_gate] ->
          [
            unload_method:
              {"not applicable for chosen vehicle class", [validation: :allowed_unload_method]}
          ]

        _ ->
          []
      end
    end)
  end

  defp validate_market(changeset) do
    market = get_field(changeset, :market)
    vehicle_class = get_field(changeset, :vehicle_class)

    if vehicle_class == 4 and not Markets.market_has_boxtrucks?(market) do
      add_error(changeset, :vehicle_class, "box trucks are not supported in this market",
        validation: :vehicle_class_supported
      )
    else
      changeset
    end
  end

  defp validate_pricing(changeset),
    do:
      changeset
      |> validate_required([
        :driver_cut,
        :driver_fees
      ])
      |> validate_number(:driver_cut, greater_than: 0)
      |> validate_number(:driver_fees, greater_than_or_equal_to: 0)
      |> validate_fee_length(:holiday_fee, max: 1)
      |> validate_fee_length(:lift_gate_fee, max: 1)
      |> validate_fee_length(:route_surcharge, max: 1)
      |> validate_fee_length(:toll_fees, max: 1)
      |> validate_fee_length(:driver_tip, max: 1)
      |> validate_fee_length(:load_fee, max: 1)
      |> validate_fee_length(:base_fee, max: 1, min: 1)

  defp validate_driver(changeset, %Driver{wallet_state: state})
       when state in [:UNCLAIMED, :ACTIVE],
       do: changeset

  defp validate_driver(changeset, _),
    do:
      Changeset.add_error(changeset, :driver_id, "must have a wallet",
        validation: :is_valid_driver
      )

  defp validate_current_state_is(changeset, states) when is_list(states) do
    validate_change(changeset, :driver_id, :current_state, fn _field, _value ->
      case get_field(changeset, :state) in states do
        true -> []
        _ -> [state: {"is not %{states}", [validation: :current_state, states: states]}]
      end
    end)
  end

  defp validate_current_state_is(changeset, state),
    do: validate_current_state_is(changeset, [state])

  defp validate_same_day(changeset) do
    validate_for_shipper(changeset, fn changeset ->
      if get_field(changeset, :service_level) == 2 do
        changeset
        |> validate_same_day_distance()
        |> validate_assoc_length(:match_stops,
          max: 10,
          message: "must be 10 or less for a Same Day Match"
        )
      end
    end)
  end

  defp validate_same_day_distance(changeset) do
    case get_field(changeset, :total_distance) do
      distance when distance > 150 ->
        add_error(
          changeset,
          :match_stops,
          "cannot be further than 150 miles for a Same Day Match",
          validation: :same_day_distance
        )

      _ ->
        changeset
    end
  end

  defp get_authorized_time(changeset),
    do: Shipment.match_authorized_time(changeset.data) || DateTime.utc_now()

  defp validate_fee_length(changeset, fee_type, opts),
    do:
      validate_assoc_length(
        changeset,
        :fees,
        opts ++ [message: "should have a %{kind} of %{count} %{fee_type}"],
        &(&1.type == fee_type),
        fee_type: fee_type
      )

  defp valid_fields(changeset) do
    @forbidden_update_fields
    |> Enum.reduce(changeset, fn field, acc ->
      if get_change(acc, field) != nil,
        do: add_error(acc, field, "cannot be updated", validation: :uneditable_field),
        else: acc
    end)
  end

  defp validate_for_shipper(%{params: %{"admin" => %AdminUser{}}} = changeset, _validator),
    do: changeset

  defp validate_for_shipper(changeset, validator), do: validator.(changeset) || changeset

  defp validate_preferred_driver_update(changeset) do
    case fetch_change(changeset, :preferred_driver_id) do
      :error ->
        changeset

      {:ok, _change} ->
        case valid_deliver_pro_update?(changeset) do
          true ->
            changeset

          false ->
            Changeset.add_error(
              changeset,
              :preferred_driver_id,
              "unable to update preferred driver"
            )
        end
    end
  end

  defp validate_platform_change(changeset) do
    case fetch_change(changeset, :platform) do
      :error ->
        changeset

      {:ok, :marketplace} ->
        case valid_deliver_pro_update?(changeset) do
          true ->
            changeset

          false ->
            Changeset.add_error(
              changeset,
              :platform,
              "can not change platform for accepted match"
            )
        end

      {:ok, :deliver_pro} ->
        case valid_deliver_pro_update?(changeset) do
          true ->
            changeset

          false ->
            Changeset.add_error(
              changeset,
              :platform,
              "invalid platform change"
            )
        end
    end
  end

  defp valid_deliver_pro_update?(%Changeset{data: %{state: :pending}}), do: true

  defp valid_deliver_pro_update?(changeset) do
    changeset.data.platform == :deliver_pro and
      changeset.data.state == :assigning_driver
  end
end
