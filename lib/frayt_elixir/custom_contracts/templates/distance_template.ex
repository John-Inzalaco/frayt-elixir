defmodule FraytElixir.CustomContracts.DistanceTemplate do
  alias FraytElixir.CustomContracts.{DistanceTemplate, ContractFees}
  alias FraytElixir.{Shipment, Repo}
  alias Shipment.{Match, MatchStop, Pricing}
  alias FraytElixir.Shipment.Address
  alias Ecto.Changeset
  alias FraytElixir.Contracts.Contract

  defmodule LevelTier do
    @enforce_keys [:default]
    defstruct @enforce_keys ++ [first: nil]

    @typedoc """
      * `default` - This is the tier used for all stops not covered by `first`
      * `first` - This is optional. The first stop will use this tier. If a tuple is used, `number_of_stops` will determine the first `number_of_stops` that will use this tier
    """
    @type t() :: %__MODULE__{
            first: nil | DistanceTier.t() | {number_of_stops :: integer(), DistanceTier.t()},
            default: DistanceTier.t()
          }
  end

  defmodule DistanceTier do
    @enforce_keys [:base_price, :base_distance, :driver_cut]
    defstruct @enforce_keys ++
                [
                  price_per_mile: nil,
                  markup: 1.0,
                  max_item_weight: nil,
                  max_weight: nil,
                  max_volume: nil,
                  per_mile_tapering: %{},
                  default_tip: nil,
                  cargo_value_cut: nil
                ]

    @typedoc """
      * `distance` - When less than or equal to this value, the corresponding price per mile will be used for all miles that fall between the current tier and the previous smaller tier
      * `price_per_mile` - The price per mile in US cents (¢) added to the `base_price`
    """
    @type tapering_tiers :: %{(distance :: float()) => price_per_mile :: integer()}

    @typedoc """
      * `price_per_mile` - The price per mile in US cents (¢) added to the `base_price`. When used in correlation with `per_mile_tapering`, this will be the final tier. When unset or `nil` any distances over `base_distance` or largest tapering tier will be invalid
      * `base_price` - The starting price in US cents (¢)
      * `base_distance` - The # of miles included in the `base_price` to be excluded from `price_per_mile`
      * `cargo_value_cut` - The percentage of the cargo value to calculate the base_price (between 1 and 0). The higher of `base_price` and the product `cargo_value_cut` will be used as the base price.
      * `driver_cut` - The percentage of the base fee the driver will receive (between 1 and 0)
      * `markup` - A float to multiply the base fee
      * `max_item_weight` - The maximum weight per item allowed for this tier in pounds (lbs)
      * `max_weight` - The maximum weight allowed for this tier in pounds (lbs)
      * `max_volume` - The maximum volume allowed for this tier in cubic inches (in³)
      * `per_mile_tapering` - Allows for tapering costs over longer distances. See `tapering_tiers` for details
    """
    @type t() :: %__MODULE__{
            price_per_mile: integer(),
            base_price: integer(),
            base_distance: integer(),
            driver_cut: float(),
            cargo_value_cut: float(),
            markup: float(),
            max_item_weight: integer(),
            max_weight: integer(),
            max_volume: integer(),
            per_mile_tapering: tapering_tiers
          }
  end

  defmodule FieldError do
    defexception [:field, :message]
  end

  @typedoc """
  All possible vehicle classes as atoms
  """
  @type vehicle_class_type :: FraytElixir.Shipment.VehicleClass.vehicle_class_type()

  @typedoc """
  List of level tiers. See `level_type` for details
  """
  @type tiers ::
          list(LevelTier.t())
          | list({vehicle_class_type, LevelTier.t()})
          | list({:dash | :scheduled, LevelTier.t()})
          | list({weight :: integer(), LevelTier.t()})

  @typedoc """
    A keyword list with the following optional values
    * `:schedule_buffer` - defaults to 8 hours in seconds
  """
  @type scheduled_type_opts :: {:schedule_buffer, integer()}

  @typedoc """
    Level type determines what rules to use to determine the tier level to use
    * `:none` - the first tier will always be used
    * `:vehicle_class` - will select the tier with the corresponding vehicle class as a `vehicle_class_type`
    * `:distance` - will select the smallest tier with a greater `base_distance` than the distance to a stop
    * `:scheduled` - if a match is scheduled with a pickup time more than `:schedule_buffer` the `:scheduled` tier will be used. If less the `:dash` tier will be used and will be converted to a dash Match. `Options can optionally be passed as {:scheduled, opts}`. See `scheduled_type_opts` for options
  """
  @type level_type ::
          :none
          | :vehicle_class
          | :distance
          | :scheduled
          | :weight
          | {:scheduled, list(scheduled_type_opts)}

  @typedoc """
  The type of distance calculation to use. Defaults to `:travel_from_prev_stop`. Possible values are:
  * `:travel_from_prev_stop` - will use the distance between stops
  * `:radius_from_origin` - will calculate the radius from the origin address
  """
  @type distance_type :: :radius_from_origin | :travel_from_prev_stop

  @typedoc """
    * `amount` - the amount the shipper will be charged in US cents (¢)
    * `driver_amount` - the amount the shipper will be charged in US cents (¢)
  """
  @type static_fee :: {amount :: integer(), driver_amount :: integer()}

  @typedoc """
    A load fee can be configured to have multiple weight tiers
    * `weight` - the minimum weight to use this pricing tier in pounds (lbs)
    * `static_fee` - the payout amount
  """
  @type load_fee :: %{(weight :: integer()) => static_fee}

  @typedoc """
    A return charge will be added as the sum of a percentage of the stop `base_price` for all stops in the `undeliverable` state. The driver will receive the same cut as the stop cut.
  """
  @type return_charge :: float()

  @typedoc """
    A preferred driver fee will be added as the percentage of sum of base price for all stops in match + sum of driver fee for all stops in match. The driver will receive 50% of the order total.
  """
  @type preferred_driver_fee :: float()

  @typedoc """
    Item weight (not the total weight)
  """
  @type item_weight_fee :: %{(weight_in_lbs :: integer()) => amount_in_cents :: integer()}

  @typedoc """
    A configurable fee. Fee types:
    * `toll_fees` - When true, will calculate the tolls and add a fee when applicable
    * `load_fee` - See the type doc for `load_fee`
    * `lift_gate_fee` - Adds a static fee when the unload method is lift gate for box trucks
    * `holiday_fee` - Adds a static fee when a delivery occurs on a holiday for box trucks
    * `route_surcharge` - Adds a static fee when there is more than 1 stop
    * `return_charge` - See the type doc for `return_charge`
    * `preferred_driver_fee` - See the type doc for `preferred_driver_fee`
  """
  @type fee ::
          {:toll_fees, enabled? :: boolean()}
          | {:load_fee, load_fee}
          | {:return_charge, return_charge}
          | {:preferred_driver_fee, preferred_driver_fee}
          | {:lift_gate_fee | :holiday_fee | :route_surcharge, static_fee}
          | {:item_weight_fee, item_weight_fee}

  @typedoc """
    State markup can markup price by states:
    * `state` - two letter code of the state
    * `markup_factor` - Multiply the base fee by this float
  """
  @type state_markups :: %{(state :: String.t()) => markup_factor :: float()}

  @typedoc """
    State markup can markup price by states:
    * `condition` - Can be set to `:weekends`, `:holidays` or a time range, both set to the local timezone of the given Match
    * `markup_factor` - Multiply the base fee by this float
  """
  @type time_surcharge ::
          {condition :: :weekends | :holidays | {start_time :: Time.t(), end_time :: Time.t()},
           markup_factor :: float()}

  @typedoc """
    A configurable markup. Markup types:
    * `:state` - See `state_markup`
    * `:market` - When enabled, a match base fee will be modified by the markups set on each market
    * `:time_surcharge` - A list of time surcharges. Only the first matched time surcharge will be applied.  See `time_surcharge` for options.
  """
  @type markup ::
          {:state, state_markups}
          | {:time_surcharge, list(time_surcharge)}
          | {:market, enabled? :: boolean()}

  @typedoc """
    Custom configuration for distance template implementation
    * `tiers` - See `tiers` for details
    * `level_type` - See `level_type` for details
    * `distance_type` - See `distance_type` for details
    * `fees` - A list of fees. See `fee` for details
    * `markups` - A list of markups. See `markup` for details
  """
  @type t() :: %__MODULE__{
          tiers: tiers,
          level_type: level_type,
          distance_type: distance_type,
          fees: list(fee),
          markups: list(markup)
        }

  @enforce_keys [:tiers, :level_type]
  defstruct @enforce_keys ++ [markups: [], fees: [], distance_type: :travel_from_prev_stop]

  @spec calculate_pricing(match :: Match.t(), config :: DistanceTemplate.t()) ::
          Ecto.Changeset.t()
  def calculate_pricing(%Match{} = match, %DistanceTemplate{} = config) do
    match = Repo.preload(match, contract: :market_configs)
    %Match{match_stops: stops} = match
    total_tips = Enum.map(stops, & &1.tip_price) |> Enum.sum()
    pricing_params = %{total_tips: total_tips, config: config}
    fee_fn = &ContractFees.calculate_fees(&1, &2, config.fees)

    case Pricing.build_pricing(match, &calculate_stop_pricing(&1, &2, pricing_params), fee_fn) do
      {:ok, attrs} ->
        Match.pricing_changeset(match, attrs)

      {:error, errors} ->
        Pricing.apply_errors(match, errors)
    end
  rescue
    error in FieldError ->
      %{field: field, message: message} = error

      match
      |> Match.pricing_changeset(%{})
      |> Changeset.add_error(field, message)
  end

  @spec include_tolls?(match :: Match.t(), config :: DistanceTemplate.t()) :: boolean()
  def include_tolls?(_match, config), do: Keyword.get(config.fees, :toll_fees, false)

  def calculate_stop_pricing(%MatchStop{} = stop, %Match{} = match) do
    calculate_stop_pricing(stop, match, %{})
  end

  def calculate_stop_pricing(stop, match, opts) do
    config = Map.fetch!(opts, :config)
    total_tips = Map.fetch!(opts, :total_tips)

    distance = get_distance(stop, config)

    tier = get_range(match, stop, distance, config)

    %MatchStop{index: index} = stop

    stop =
      if total_tips == 0 and index == 0 and !is_nil(tier.default_tip) and
           tier.default_tip != 0 do
        %{stop | tip_price: tier.default_tip}
      else
        stop
      end

    markup = calculate_markups(match, config) * tier.markup

    with {:ok, _} <- validate_weight_and_volume(match, stop, tier),
         {:ok, base_price} <- calculate_base_price(stop, distance, markup, tier) do
      {:ok,
       %{
         tip_price: stop.tip_price,
         base_price: base_price,
         driver_cut: tier.driver_cut
       }}
    end
  end

  defp calculate_markups(match, config) do
    markups = [{:contract_market, true} | config.markups]

    Enum.reduce(markups, 1, fn {type, opts}, markup ->
      get_markup(type, opts, match) * markup
    end)
  end

  @get_time_surcharge Application.compile_env(
                        :frayt_elixir,
                        :get_time_surcharge,
                        &__MODULE__.get_time_surcharge/2
                      )

  def get_markup(type, opts, match)

  def get_markup(:contract_market, true, %Match{contract: %Contract{}} = match) do
    case Enum.find(match.contract.market_configs, &(&1.market_id == match.market_id)) do
      nil -> 1
      config -> config.multiplier
    end
  end

  def get_markup(:state, state_markups, match) do
    %Match{origin_address: %Address{state_code: state_code}} = match

    Enum.find_value(state_markups, 1, fn {state, markup} ->
      if state == state_code, do: markup
    end)
  end

  def get_markup(:market, true, match), do: match.markup

  def get_markup(:time_surcharge, opts, match), do: @get_time_surcharge.(match, opts)

  def get_markup(_type, _opts, _match), do: 1

  def get_time_surcharge(%DateTime{} = date_time, opts) do
    day = date_time |> DateTime.to_date() |> Date.day_of_week(:monday)

    {weekend_markup, opts} = Keyword.pop(opts, :weekends, 1)
    {holiday_markup, time_markups} = Keyword.pop(opts, :holidays, 1)

    cond do
      is_holiday?(date_time) and holiday_markup != 1 ->
        holiday_markup

      day in [6, 7] and weekend_markup != 1 ->
        weekend_markup

      true ->
        time = DateTime.to_time(date_time)

        Enum.find_value(time_markups, 1, &get_markup_for_time(&1, time))
    end
  end

  def get_time_surcharge(%Match{scheduled: true} = match, opts) do
    %Match{pickup_at: pickup_at, timezone: timezone} = match

    get_time_surcharge(pickup_at, timezone, opts)
  end

  def get_time_surcharge(%Match{scheduled: false} = match, opts) do
    date_time = Shipment.match_authorized_time(match) || DateTime.utc_now()
    get_time_surcharge(date_time, match.timezone, opts)
  end

  def get_time_surcharge(nil, _timezone, _opts), do: 1

  def get_time_surcharge(date_time, timezone, opts) do
    date_time = Timex.to_datetime(date_time, "UTC")

    date_time =
      case Timex.to_datetime(date_time, timezone) do
        %DateTime{} = lc_date_time -> lc_date_time
        _ -> date_time
      end

    get_time_surcharge(date_time, opts)
  end

  defp is_holiday?(date_time) do
    date = DateTime.to_date(date_time)

    case Holidefs.on(:fed, date) do
      {:ok, holidays} -> length(holidays) > 0
      _ -> false
    end
  end

  defp get_markup_for_time({{start_time, end_time}, markup}, time) do
    after_start? = Time.compare(time, start_time) == :gt
    before_end? = Time.compare(time, end_time) == :lt
    start_after_end? = Time.compare(start_time, end_time) == :gt

    cond do
      start_after_end? and (after_start? or before_end?) -> markup
      not start_after_end? and after_start? and before_end? -> markup
      true -> nil
    end
  end

  defp validate_weight_and_volume(%{total_weight: total_weight}, _stop, %DistanceTier{
         max_weight: max_weight
       })
       when not is_nil(max_weight) and total_weight > max_weight,
       do:
         {:error, {:match, :total_weight}, "cannot be over %{limit} lbs total",
          [validation: :max_weight, limit: max_weight]}

  defp validate_weight_and_volume(%{total_volume: total_volume}, _stop, %DistanceTier{
         max_volume: max_volume
       })
       when not is_nil(max_volume) and total_volume / 1728 > max_volume,
       do:
         {:error, {:match, :total_volume}, "cannot be over %{limit} ft³ total",
          [validation: :max_volume, limit: max_volume]}

  defp validate_weight_and_volume(match, stop, tier) do
    %{max_item_weight: max_item_weight} = tier

    above_weight? =
      not is_nil(max_item_weight) and Enum.any?(stop.items, &(&1.weight > max_item_weight))

    if above_weight? do
      {:error, :items, "cannot be over %{limit} lbs for an item",
       [validation: :max_item_weight, limit: max_item_weight]}
    else
      {:ok, match}
    end
  end

  defp calculate_base_price(
         stop,
         distance,
         markup,
         %DistanceTier{
           cargo_value_cut: cargo_value_cut
         } = tier
       )
       when not is_nil(cargo_value_cut) do
    total_value =
      stop.items
      |> Enum.map(&(&1.declared_value || 0))
      |> Enum.sum()

    total_value_cut = round(total_value * cargo_value_cut)

    tier = %{tier | base_price: max(total_value_cut, tier.base_price)}

    calculate_base_price(distance, markup, tier)
  end

  defp calculate_base_price(_stop, distance, markup, tier),
    do: calculate_base_price(distance, markup, tier)

  defp calculate_base_price(distance, markup, %DistanceTier{
         base_distance: base_distance,
         base_price: base_price
       })
       when distance <= base_distance,
       do: {:ok, round(base_price * markup)}

  defp calculate_base_price(distance, markup, tier) do
    %DistanceTier{
      base_distance: base_distance,
      base_price: base_price,
      price_per_mile: price_per_mile,
      per_mile_tapering: per_mile_tapering
    } = tier

    with :ok <- validate_distance(distance, tier) do
      {total_price, _} =
        per_mile_tapering
        |> Enum.sort_by(&elem(&1, 0), :asc)
        |> List.insert_at(-1, {nil, price_per_mile})
        |> Enum.reduce({base_price, base_distance}, fn {taper_distance, taper_per_mile},
                                                       {subtotal, prev_distance} ->
          if taper_per_mile do
            distance_in_taper = min(distance, taper_distance)
            subtotal = subtotal + max(distance_in_taper - prev_distance, 0) * taper_per_mile
            {subtotal, taper_distance}
          else
            {subtotal, taper_distance}
          end
        end)

      {:ok, round(total_price * markup)}
    end
  end

  defp validate_distance(distance, tier) do
    %DistanceTier{
      base_distance: base_distance,
      price_per_mile: price_per_mile,
      per_mile_tapering: per_mile_tapering
    } = tier

    max_distance =
      per_mile_tapering
      |> Enum.map(fn {distance, _} -> distance end)
      |> Enum.max(fn -> base_distance end)

    cond do
      not is_nil(price_per_mile) ->
        :ok

      distance <= max_distance ->
        :ok

      true ->
        {:error, :distance, "cannot be over %{limit} miles",
         [validation: :mile_limit, limit: max_distance]}
    end
  end

  defp get_distance(stop, %DistanceTemplate{distance_type: :travel_from_prev_stop}),
    do: stop.distance

  defp get_distance(stop, %DistanceTemplate{distance_type: :radius_from_origin}),
    do: stop.radial_distance

  defp get_range(match, %MatchStop{index: index} = stop, distance, config),
    do:
      select_tier(match, stop, distance, config)
      |> select_distance_tier(index)

  defp select_distance_tier(%LevelTier{first: %DistanceTier{} = dis_tier}, 0), do: dis_tier

  defp select_distance_tier(%LevelTier{first: {limit, %DistanceTier{} = dis_tier}}, index)
       when index <= limit,
       do: dis_tier

  defp select_distance_tier(%LevelTier{default: dis_tier}, _index), do: dis_tier

  defp select_tier(match, stop, distance, config) do
    %DistanceTemplate{tiers: tiers} = config

    {level_type, level_type_opts} =
      case config.level_type do
        {type, opts} -> {type, opts}
        type -> {type, []}
      end

    case level_type do
      :none -> List.first(tiers)
      :distance -> get_distance_tier(stop, distance, tiers)
      :vehicle_class -> get_vehicle_class_tier(match, tiers)
      :scheduled -> get_scheduled_tier(match, tiers, level_type_opts)
      :weight -> get_weight_tier(match, tiers)
    end
  end

  defp get_distance_tier(stop, distance, tiers) do
    max_tier = Enum.max_by(tiers, &select_distance_tier(&1, stop.index).base_distance)

    tiers
    |> Enum.sort_by(&select_distance_tier(&1, stop.index).base_distance)
    |> Enum.find(
      max_tier,
      &(distance <= select_distance_tier(&1, stop.index).base_distance)
    )
  end

  defp get_vehicle_class_tier(match, tiers) do
    vehicle_class = Shipment.vehicle_classes(match.vehicle_class)
    tier = Keyword.get(tiers, vehicle_class)

    if is_nil(tier),
      do: raise(FieldError, field: :vehicle_class, message: "is not supported in this contract")

    tier
  end

  defp get_scheduled_tier(match, tiers, opts) do
    case match do
      %Match{scheduled: false} ->
        Keyword.fetch!(tiers, :dash)

      %Match{scheduled: true, pickup_at: pickup_at} ->
        match = match |> Repo.preload(:state_transitions)

        authorized_time =
          Shipment.match_transitioned_at(match, :scheduled, :asc) || NaiveDateTime.utc_now()

        schedule_buffer = Keyword.get(opts, :schedule_buffer, 8 * 60 * 60)

        key =
          case NaiveDateTime.diff(pickup_at, authorized_time, :second) do
            s when s >= schedule_buffer -> :scheduled
            _ -> :dash
          end

        Keyword.fetch!(tiers, key)
    end
  end

  defp get_weight_tier(match, tiers) do
    tier =
      tiers
      |> Enum.sort_by(fn {weight, _} -> weight end)
      |> Enum.find_value(fn {weight, tier} -> if match.total_weight <= weight, do: tier end)

    if is_nil(tier),
      do: raise(FieldError, field: :weight, message: "is not supported in this contract")

    tier
  end
end
