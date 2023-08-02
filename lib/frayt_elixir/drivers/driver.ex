defmodule FraytElixir.Drivers.Driver do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema
  import Ecto.Query
  alias FraytElixir.Repo
  alias FraytElixir.Drivers.{WalletEnum, Proficience, VehicleDocument}
  alias FraytElixir.Accounts.{DriverSchedule, Schedule, User}
  alias FraytElixir.{Sanitizers, Shipment}
  alias Shipment.{Address, Match, HiddenMatch}
  alias FraytElixir.Devices.DriverDevice
  alias FraytElixir.Markets.Market

  alias FraytElixir.Drivers.{
    DriverStateTransition,
    DriverState,
    Vehicle,
    DriverLocation,
    DriverMetrics,
    HiddenCustomer,
    DriverDocument
  }

  alias FraytElixir.Payments.DriverBonus
  alias FraytElixir.Screenings.BackgroundCheck
  alias FraytElixir.Type.PhoneNumber
  import FraytElixir.DistanceConversion
  import FraytElixir.Guards
  import Geo.PostGIS

  schema "drivers" do
    field :first_name, :string
    field :last_name, :string
    field :license_number, :string
    field :license_state, :string
    field :phone_number, PhoneNumber
    field :ssn, :string
    field :citizenship, CountryEnum, default: nil
    field :state, DriverState.Type, default: :applying
    field :fleet_opt_state, DriverFleetOptEnum, default: :opted_in
    field :fountain_id, :string
    field :can_load, :boolean
    field :birthdate, :date
    field :penalties, :integer, default: 0
    field :notes, :string
    field :wallet_state, WalletEnum, default: nil
    field :sms_opt_out, :boolean, default: false
    field :page_count, :integer, virtual: true
    field :active_match_limit, :integer, default: nil
    field :english_proficiency, Proficience.Type
    field :current_location_inserted_at, :naive_datetime
    field :applied_at, :naive_datetime, virtual: true

    belongs_to :current_location, DriverLocation, on_replace: :nilify
    belongs_to :user, User
    belongs_to :address, Address, on_replace: :update
    belongs_to :default_device, DriverDevice, on_replace: :nilify
    belongs_to :market, Market

    has_many :vehicles, Vehicle
    has_many :images, DriverDocument, on_delete: :nothing
    has_many :driver_locations, DriverLocation
    has_many :hidden_matches, HiddenMatch
    has_many :hidden_customers, HiddenCustomer
    has_many :matches, Match
    has_many :driver_bonuses, DriverBonus
    has_many :devices, DriverDevice
    has_many :state_transitions, DriverStateTransition

    has_one :metrics, DriverMetrics
    has_one :background_check, BackgroundCheck

    many_to_many :schedules, Schedule, join_through: DriverSchedule

    timestamps()
  end

  def poorly_rated_matches(id) do
    from(d in __MODULE__,
      left_join: m in assoc(d, :matches),
      where: d.id == ^id and m.rating < 5,
      select: %{
        match_id: m.id,
        match_shortcode: m.shortcode,
        rating: m.rating,
        reason: m.rating_reason
      }
    )
  end

  def filter_by_pickup(query, _driver_location, pickup_point, _search_radius)
      when is_nil(pickup_point),
      do: query

  def filter_by_pickup(query, :current_location, pickup_point, search_radius),
    do: filter_by_pickup_from_current_location(query, pickup_point, search_radius)

  def filter_by_pickup(query, :address, pickup_point, search_radius),
    do: filter_by_pickup_from_home(query, pickup_point, search_radius)

  def filter_by_pickup_from_home(query, pickup_point, search_radius)
      when is_number(search_radius) do
    radius_in_meters = miles_to_meters(search_radius)

    from m in query,
      left_join: address in Address,
      on: m.address_id == address.id,
      group_by: [address.geo_location, m.id],
      where: st_distance_in_meters(address.geo_location, ^pickup_point) < ^radius_in_meters,
      order_by: [asc: st_distance_in_meters(address.geo_location, ^pickup_point)]
  end

  def filter_by_pickup_from_home(query, pickup_point, _),
    do:
      from(m in query,
        left_join: address in Address,
        on: m.address_id == address.id,
        group_by: [address.geo_location, m.id],
        order_by: [asc: st_distance_in_meters(address.geo_location, ^pickup_point)]
      )

  def filter_by_pickup_from_current_location(query, pickup_point, search_radius)
      when is_number(search_radius) do
    radius_in_meters = miles_to_meters(search_radius)

    from d in query,
      left_join: current_loc in DriverLocation,
      on: d.current_location_id == current_loc.id,
      where: st_distance_in_meters(current_loc.geo_location, ^pickup_point) < ^radius_in_meters,
      order_by: [asc: st_distance_in_meters(current_loc.geo_location, ^pickup_point)]
  end

  def filter_by_pickup_from_current_location(query, pickup_point, _) do
    from d in query,
      left_join: current_loc in DriverLocation,
      on: d.current_location_id == current_loc.id,
      group_by: [current_loc.geo_location, d.id],
      order_by: [asc: st_distance_in_meters(current_loc.geo_location, ^pickup_point)]
  end

  def filter_by_updated(query, activity_recency)
      when activity_recency == "last_24_hours" do
    from(m in query,
      where: fragment("? > now() - interval '24hour'", m.updated_at)
    )
  end

  def filter_by_updated(query, activity_recency)
      when activity_recency == "last_12_hours" do
    from(m in query,
      where: fragment("? > now() - interval '12hour'", m.updated_at)
    )
  end

  def filter_by_updated(query, activity_recency)
      when activity_recency == "last_hour" do
    from(m in query,
      where: fragment("? > now() - interval '1hour'", m.updated_at)
    )
  end

  def filter_by_background_check_state(query, nil), do: query

  def filter_by_background_check_state(query, state) do
    from(d in query,
      join: bgc in assoc(d, :background_check),
      on: bgc.driver_id == d.id,
      where: bgc.turn_state == ^state
    )
  end

  def filter_by_vehicle_type(query, nil), do: query

  def filter_by_vehicle_type(query, vehicle_type) when is_number(vehicle_type),
    do: filter_by_vehicle_type(query, [vehicle_type])

  def filter_by_vehicle_type(query, vehicle_type) when length(vehicle_type) in [0, 4], do: query

  def filter_by_vehicle_type(query, vehicle_type) do
    vehicle_query =
      from(d in __MODULE__,
        full_join: v in assoc(d, :vehicles),
        where: v.vehicle_class in ^vehicle_type,
        group_by: d.id,
        distinct: d.id
      )

    from(m in query,
      join: dv in subquery(vehicle_query),
      on: m.id == dv.id
    )
  end

  def filter_by_sms_opt_out(query, true), do: from(d in query, where: d.sms_opt_out == true)

  def filter_by_sms_opt_out(query, false),
    do: from(d in query, where: d.sms_opt_out == false or is_nil(d.sms_opt_out))

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(d in query,
        left_join: a in assoc(d, :address),
        join: u in assoc(d, :user),
        left_join: v in Vehicle,
        on: v.driver_id == d.id,
        where:
          ilike(fragment("CONCAT(?, ' ', ?)", d.first_name, d.last_name), ^"%#{search_query}%"),
        or_where: ilike(fragment("CONCAT(?, ', ', ?)", a.city, a.state), ^"%#{search_query}%"),
        or_where: ilike(d.phone_number, ^"%#{search_query}%"),
        or_where: ilike(u.email, ^"%#{search_query}%")
      )

  def filter_by_state(query, nil), do: query

  def filter_by_state(query, :active),
    do: from(d in query, where: d.state in [:approved, :registered, :disabled])

  def filter_by_state(query, :all_applicants),
    do:
      from(
        d in query,
        where: d.state in [:applying, :pending_approval, :screening, :rejected]
      )

  def filter_by_state(query, state), do: from(d in query, where: d.state == ^state)

  def filter_by_document_state(query, nil), do: query

  def filter_by_document_state(query, state) do
    check_state =
      case state do
        :expired ->
          dynamic(
            [vdocs: vd, ddocs: dd],
            fragment("? < CURRENT_DATE", vd.expires_at) or
              fragment("? < CURRENT_DATE", dd.expires_at)
          )

        :approved ->
          dynamic([vdocs: vd, ddocs: dd], vd.state == :approved and dd.state == :approved)

        state ->
          dynamic([vdocs: vd, ddocs: dd], vd.state == ^state or dd.state == ^state)
      end

    from(d in query,
      join:
        docs in subquery(
          from(d0 in __MODULE__,
            left_join:
              ddocs in subquery(
                from(dd in DriverDocument,
                  order_by: [desc: dd.inserted_at],
                  distinct: [dd.type, dd.driver_id],
                  select: %{driver_id: dd.driver_id, expires_at: dd.expires_at, state: dd.state}
                )
              ),
            on: d0.id == ddocs.driver_id,
            as: :ddocs,
            left_join:
              vdocs in subquery(
                from(v in Vehicle,
                  left_join: vd in VehicleDocument,
                  on: vd.vehicle_id == v.id,
                  order_by: [desc: vd.inserted_at],
                  distinct: [vd.type, v.driver_id],
                  select: %{driver_id: v.driver_id, expires_at: vd.expires_at, state: vd.state}
                )
              ),
            on: d0.id == vdocs.driver_id,
            as: :vdocs,
            where: ^check_state,
            group_by: d0.id,
            select: %{driver_id: d0.id}
          )
        ),
      on: docs.driver_id == d.id
    )
  end

  def filter_by_market_id(query, nil), do: query

  def filter_by_market_id(query, market_id),
    do: from(d in query, where: d.market_id == ^market_id)

  def current_location(query, true) do
    from driver in query,
      full_join: current_loc in DriverLocation,
      on: current_loc.id == driver.current_location_id,
      group_by: [
        current_loc.id,
        current_loc.geo_location,
        current_loc.formatted_address,
        current_loc.driver_id,
        current_loc.inserted_at,
        current_loc.updated_at,
        driver.id
      ],
      where: not is_nil(current_loc)
  end

  def current_location(query, false) do
    query
  end

  def current_location(query), do: current_location(query, false)

  def full_match_id_on_driver(query, driver_id, match_id) do
    from(driver in query,
      left_join: match in assoc(driver, :matches),
      where:
        driver.id == ^driver_id and
          (ilike(fragment("CAST(? as text)", match.id), ^"#{match_id}%") or
             ilike(match.shortcode, ^"#{match_id}")),
      select: match.id
    )
  end

  def approved_drivers(query) do
    from(driver in query,
      where: driver.state in ["approved", "registered"]
    )
  end

  def get_driver_by_email(query, driver_email),
    do:
      from(d in query,
        as: :driver,
        join: u in assoc(d, :user),
        where: u.email == ^driver_email
      )

  @allowed ~w(
    first_name last_name phone_number license_number license_state can_load
    birthdate penalties notes user_id fleet_opt_state wallet_state
    active_match_limit default_device_id english_proficiency market_id
    address_id ssn
  )a

  @required ~w(
    first_name last_name phone_number license_number market_id birthdate
    user_id english_proficiency address_id ssn
  )a

  def changeset(driver, attrs) do
    driver
    |> cast(attrs, @allowed)
    |> cast_assoc(:vehicles)
    |> changeset_common(driver)
  end

  defp changeset_common(cs, driver) do
    cs
    |> cast_assoc(:metrics)
    |> Address.assoc_address(driver, :address)
    |> Sanitizers.strip_nondigits(:ssn)
    |> validate_required([:phone_number])
    |> validate_length(:ssn, is: 9, message: "should be 9 numbers")
    |> validate_number(:penalties,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5,
      message: "must be between 0 and 5"
    )
    |> validate_number(:active_match_limit,
      not_equal_to: 0,
      message: "must be greater then 0 or empty/default"
    )
    |> validate_phone_number(:phone_number)
  end

  def update_driver_state_changeset(driver, %DriverStateTransition{} = state_transition) do
    driver
    |> change(%{state: state_transition.to})
    |> put_assoc(:state_transitions, [state_transition | driver.state_transitions])
  end

  @doc false
  def update_changeset(driver, attrs) do
    driver
    |> changeset(attrs)
    |> validate_required([:first_name, :last_name])
  end

  def complete_driver_changeset(driver, attrs) do
    driver
    |> Repo.preload(:images, vehicles: [:images])
    |> changeset(attrs)
    |> cast_assoc(:images, required: true, with: &DriverDocument.changeset/2)
    |> cast_assoc(:vehicles, required: true, with: &Vehicle.document_changeset/2)
    |> validate_required(@required)
    |> validate_required_documents()
  end

  @image_types ~w(
    back cargo_area drivers_side front passengers_side insurance registration
    license
  )a

  defp validate_required_documents(changeset) do
    driver_imgs = get_field(changeset, :images) || []

    vehicle_imgs =
      case get_field(changeset, :vehicles) do
        nil -> []
        [vehicle | _] -> Repo.preload(vehicle, :images) |> Map.get(:images, [])
      end

    case driver_imgs ++ vehicle_imgs do
      [] ->
        add_error(changeset, :images, "are all required")

      images ->
        imgs_map = Enum.reduce(images, %{}, &Map.put(&2, &1.type, &1))

        if Enum.any?(@image_types, &(!Map.has_key?(imgs_map, &1))) do
          add_error(changeset, :images, "are all required")
        else
          changeset
        end
    end
  end

  def document_changeset(driver, attrs) do
    driver
    |> cast(attrs, [])
    |> cast_assoc(:images)
    |> cast_assoc(:vehicles, with: &Vehicle.document_changeset/2)
  end

  def preapproval_changeset(driver, attrs) do
    driver
    |> changeset(attrs)
    |> validate_required([:license_number, :first_name, :last_name])
  end

  def wallet_changeset(driver, attrs) do
    driver
    |> cast(attrs, [:wallet_state])
    |> validate_required([:wallet_state])
  end

  def identity_changeset(driver, attrs) do
    driver
    |> cast(attrs, [:ssn, :birthdate, :citizenship])
    |> Sanitizers.strip_nondigits(:ssn)
    |> validate_required(:birthdate)
    |> validate_required_when(:ssn, [{:citizenship, :equal_to, :US}])
    |> validate_length(:ssn, is: 9)
  end

  def current_location_changeset(driver, %Geo.Point{} = geo_location) do
    inserted_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    attrs = %{
      current_location_inserted_at: inserted_at,
      current_location: %{
        inserted_at: inserted_at,
        driver_id: driver.id,
        geo_location: geo_location
      }
    }

    driver
    |> cast(attrs, [:current_location_inserted_at])
    |> cast_assoc(:current_location)
  end

  def applying_changeset(driver, attrs, hiring_vehicle_class \\ []) do
    driver
    |> cast(attrs, @allowed)
    |> cast_assoc(:vehicles, required: true, with: &Vehicle.applying_driver_changeset/2)
    |> validate_hiring_vehicle(hiring_vehicle_class)
    |> changeset_common(driver)
  end

  defp validate_hiring_vehicle(cs, hiring_vehicles) do
    vehicle_changeset = List.first(cs.changes[:vehicles])

    vehicle_class =
      vehicle_changeset.changes[:vehicle_class]
      |> FraytElixir.Utils.vehicle_class_integer_to_atom()

    hiring_vehicle_class? = Enum.any?(hiring_vehicles, &(&1 == vehicle_class))

    if hiring_vehicle_class? do
      cs
    else
      msg = "The market you're applying is not accepting that vehicle type at this moment."
      add_error(cs, :vehicle_class, msg)
    end
  end
end
