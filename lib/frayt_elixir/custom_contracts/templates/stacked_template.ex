defmodule FraytElixir.CustomContracts.StackedTemplate do
  alias FraytElixir.CustomContracts.{StackedTemplate, ContractFees}
  alias FraytElixir.Shipment
  alias Shipment.{Match, MatchStop, Pricing, Address}

  defmodule Tier do
    defstruct parameters: [],
              service_level: nil,
              driver_cut: nil,
              per_mile: nil,
              zones: %{}

    @type parameter_key :: :weight | :pieces | :dimensions

    @type parameter ::
            {:pieces, max_count :: integer()}
            | {:weight, max_weight :: integer()}
            | {:dimensions, {width :: integer(), length :: integer(), height :: integer()}}

    @typedoc """
    A Tier sets limits based off of parameters to determine pricing
    * `parameters` - filters tier by ensuring values are below this parameter.
    * `service_level` - specifies whether it is dash(1) or same_day(2)
    * `per_mile` - specifies the price when stacke.
    * `driver_cut` - specifies the percentage that corresponds to pay the driver. (it should be between 0 and 1)
    * `zones` - ranges on which the charges will be applied according to the service_level and parameters to aggregate.
    """
    @type t() :: %__MODULE__{
            parameters: keyword(parameter),
            service_level: integer(),
            per_mile: integer() | nil,
            driver_cut: float(),
            zones: %{float() => %{price: integer(), driver_cut: float()}}
          }
  end

  @typedoc """
  State markup works by checking the key against the origin address state and multiplying it by the value.
  E.g.: If california is 12.5% more expensive than the base price then we must add `"CA" => 1.125` to the map.
  """
  @type state_markup :: %{String.t() => float()}

  @typedoc """
  Options
  * `tiers` - a collection of tiers that will be evaluated by their individual `parameters`' limits. They will be evaluated in the order listed, from top to bottom
  * `state_markup` - the percentage that pricing in a given US state should be multiplied by
  * `stack_tiers?` - default = `true`. When true, if a parameter surpasses the maximum tier, it use the highest tier combined with the smallest tier it can use to cover the total. There is no limit to the number of tiers this can stack. E.g., the biggest tiers are 100lbs, and the weight is 200 lbs, we would stack the high tier with a low tier to cover the weight.
  * `stacked_driver_cut` - the driver cut to be used if multiple tiers are stacked
  * `parameters` - the fields to be aggregated for later evaluation. All `parameters` used in tiers must be listed here
  """
  @type t() :: %__MODULE__{
          tiers: keyword(Type.t()),
          state_markup: state_markup(),
          stack_tiers?: boolean(),
          stacked_driver_cut: float(),
          parameters: list(Tier.parameter_key()),
          fees: list()
        }

  defstruct [
    :tiers,
    :state_markup,
    :stacked_driver_cut,
    stack_tiers?: true,
    parameters: [],
    fees: []
  ]

  @spec calculate_pricing(match :: Match.t(), config :: StackedTemplate.t()) ::
          Ecto.Changeset.t()
  def calculate_pricing(%Match{} = match, %StackedTemplate{} = config) do
    fee_fn = &ContractFees.calculate_fees(&1, &2, config.fees)

    case Pricing.build_pricing(match, &calculate_stop_pricing(&1, &2, config), fee_fn) do
      {:ok, attrs} -> Match.pricing_changeset(match, attrs)
      {:error, errors} -> Pricing.apply_errors(match, errors)
    end
  end

  defp calculate_stop_pricing(%MatchStop{distance: distance} = stop, %Match{} = match, opts) do
    %{service_level: service_level} = match
    parameter = Map.get(opts, :parameters, [])
    state_markup = Map.get(opts, :state_markup, %{})

    values = Enum.map(parameter, &{&1, get_parameter_value(&1, stop)})

    with {:ok, tiers} <- get_tiers(values, service_level, opts),
         {:ok, {price, driver_cut}} <- calculate_price(tiers, distance, opts) do
      {:ok,
       %{
         tip_price: calculate_markup_tip(match, price, state_markup),
         base_price: ceil(price),
         driver_cut: driver_cut
       }}
    end
  end

  defp calculate_markup_tip(_, _, state_markup) when is_nil(state_markup), do: 0

  defp calculate_markup_tip(match, base_price, state_markup) do
    %Match{
      origin_address: %Address{state_code: state}
    } = match

    state_markup_keys = Map.keys(state_markup)

    if length(state_markup_keys) > 0 do
      case state in state_markup_keys do
        true -> floor(base_price * state_markup[state])
        false -> 0
      end
    else
      0
    end
  end

  defp get_parameter_value(:pieces, %MatchStop{items: items}) do
    Enum.reduce(items, 0, fn %{pieces: pieces}, p ->
      p + pieces
    end)
  end

  defp get_parameter_value(:dimensions, %MatchStop{items: items}) do
    Enum.reduce(items, {0, 0, 0}, fn item, {max_width, max_height, max_length} ->
      %{length: curr_length, width: curr_width, height: curr_height} = item
      max_length = get_max_value(max_length, curr_length)
      max_height = get_max_value(max_height, curr_height)
      max_width = get_max_value(max_width, curr_width)

      {max_width, max_height, max_length}
    end)
  end

  defp get_parameter_value(parameter, %MatchStop{items: items}) do
    Enum.reduce(items, 0, fn item, acc ->
      acc + Map.get(item, parameter) * item.pieces
    end)
  end

  defp get_max_value(initial, actual) when initial > actual, do: initial
  defp get_max_value(_initial, actual), do: actual

  defp get_tiers(values, service_level, %__MODULE__{} = config) do
    %{parameters: parameters, stack_tiers?: stack_tiers?} = config

    case list_service_level_tiers(service_level, config) do
      [_ | _] = tiers ->
        {parameter, tier_counts} =
          parameters
          |> Enum.map(&get_tiers_for_parameter(&1, tiers, values))
          |> highest_tiers()

        check_tier_limit(stack_tiers?, tier_counts, parameter)

      _ ->
        {:error, {:match, :service_level}, "is invalid", [validation: :available_service_level]}
    end
  end

  defp list_service_level_tiers(service_level, config) do
    %{tiers: tiers} = config

    Enum.filter(tiers, fn {_, tier} -> tier.service_level == service_level end)
  end

  defp get_tiers_for_parameter(parameter, tiers, values) do
    max_tier = max_tier_for(tiers, parameter)
    value = Keyword.get(values, parameter)
    {parameter, get_stacked_tiers(tiers, parameter, max_tier, value)}
  end

  defp check_tier_limit(true, tier_counts, _parameter), do: {:ok, tier_counts}

  defp check_tier_limit(false, [{_tier, 1}] = tier_counts, _parameter), do: {:ok, tier_counts}

  defp check_tier_limit(false, _tier_counts, parameter),
    do:
      {:error, {:match, :contract}, "is above the #{parameter} limit for this contract",
       [validation: :available_service_level]}

  defp get_stacked_tiers(tiers, parameter, {max_tier_key, max_value, max_tier_index}, value)
       when value > max_value do
    case count_tiers(value, max_value) do
      {tier_count, nil} ->
        %{max_tier_key => {tier_count, max_tier_index}}

      {tier_count, remainder} ->
        case get_smallest_tier(tiers, parameter, remainder) do
          {^max_tier_key, _tier, max_tier_index} ->
            %{max_tier_key => {tier_count + 1, max_tier_index}}

          {other_tier_key, _tier, other_index} ->
            %{
              max_tier_key => {tier_count, max_tier_index},
              other_tier_key => {1, other_index}
            }
        end
    end
  end

  defp get_stacked_tiers(tiers, parameter, _max_tier, value) do
    {tier_key, _tier, index} = get_smallest_tier(tiers, parameter, value)
    %{tier_key => {1, index}}
  end

  defp count_tiers(value, max_value) when is_number(value) and is_number(max_value) do
    with {tier_count, [remainder]} <- count_tiers([value], [max_value]) do
      {tier_count, remainder}
    end
  end

  defp count_tiers(values, max_values) when is_tuple(values) and is_tuple(max_values) do
    values = Tuple.to_list(values)
    max_values = Tuple.to_list(max_values)

    with {tier_count, remainder} when is_list(remainder) <- count_tiers(values, max_values) do
      {tier_count, List.to_tuple(remainder)}
    end
  end

  defp count_tiers(values, max_values, acc \\ 0) when is_list(values) and is_list(max_values) do
    values = Enum.sort(values)
    max_values = Enum.sort(max_values)

    if Enum.any?(values, &is_nil(&1)) do
      {1, nil}
    else
      reduced_values =
        Enum.zip(values, max_values)
        |> Enum.map(fn {value, max_values} -> value - max_values end)

      cond do
        # If there are any values above 0, there are more tiers to count
        Enum.any?(reduced_values, &(&1 > 0)) -> count_tiers(reduced_values, max_values, acc + 1)
        # If there are any values less than 0, we may be able to use a smaller tier, so ignore the last tier
        Enum.any?(reduced_values, &(&1 < 0)) -> {acc, Enum.sort(values)}
        # If an exact match, add the last tier
        true -> {acc + 1, nil}
      end
    end
  end

  defp get_smallest_tier(tiers, parameter, value) do
    tiers
    |> Enum.with_index()
    |> Enum.map(fn {{tier_key, tier}, index} -> {tier_key, tier, index} end)
    |> Enum.find(fn {_tier_key, tier, _index} ->
      value <= Keyword.get(tier.parameters, parameter)
    end)
  end

  defp max_tier_for(tiers, parameter) do
    tiers
    |> Enum.with_index()
    |> Enum.map(fn {{tier_key, tier}, index} ->
      {tier_key, Keyword.get(tier.parameters, parameter), index}
    end)
    |> Enum.max_by(fn {_tier_key, max, _index} -> max end)
  end

  defp highest_tiers(tiers) do
    # when choosing the max, we prioritize the largest number of tiers. When the number of tiers is the same,
    # we look at the size of each tier by assuming that tiers are entered in order of smallest to largest

    {parameter, tiers} =
      tiers
      |> Enum.max_by(&sum_tiers(tiers, &1))

    tier_counts = Enum.map(tiers, fn {tier_key, {count, _index}} -> {tier_key, count} end)

    {parameter, tier_counts}
  end

  defp sum_tiers(tiers, {_tier_key, tier_values}) do
    tier_values
    |> Map.values()
    |> Enum.reduce({0, 0}, fn {c, i}, {count, index} ->
      # We subtract the number of tiers from the index so that multiple low value contracts are valued less than one high value contract
      {c + count, i + index - length(tiers)}
    end)
  end

  defp calculate_price(tiers, distance, %__MODULE__{} = opts) when is_list(tiers) do
    %{tiers: tiers_params, stack_tiers?: stack_tiers?} = opts

    stacked_driver_cut =
      Map.get(opts, :stacked_driver_cut) ||
        if stack_tiers?,
          do: raise(ArgumentError, "expected :stacked_driver_cut to be given as an option")

    pricings =
      tiers
      |> Enum.map(fn {key, count} ->
        tiers_params
        |> Keyword.get(key)
        |> calculate_price(distance, tiers_params)
        |> case do
          {:ok, price, driver_cut} ->
            List.duplicate({price, driver_cut}, count)

          {:error, _, _, _} = error ->
            error
        end
      end)
      |> List.flatten()

    pricing_error = Enum.find(pricings, fn pricing -> elem(pricing, 0) == :error end)

    cond do
      not is_nil(pricing_error) ->
        pricing_error

      Enum.count(pricings) == 1 ->
        {:ok, pricings |> List.first()}

      true ->
        {:ok, {pricings |> Enum.map(&elem(&1, 0)) |> Enum.sum(), stacked_driver_cut}}
    end
  end

  defp calculate_price(
         %Tier{per_mile: per_mile, zones: zones, driver_cut: driver_cut},
         distance,
         _
       ) do
    zones
    |> Enum.sort_by(fn {incl_distance, _} -> incl_distance end)
    |> Enum.find(fn {incl_distance, _} -> distance <= incl_distance end)
    |> case do
      nil ->
        {incl_distance, %{price: price}} =
          Enum.max_by(zones, &elem(&1, 0), fn -> {0, %{price: 0}} end)

        if per_mile do
          {:ok, price + (distance - incl_distance) * per_mile, driver_cut}
        else
          {:error, :distance, "cannot be over %{limit} miles",
           [validation: :mile_limit, limit: incl_distance]}
        end

      {_, %{price: price, driver_cut: driver_cut}} ->
        {:ok, price, driver_cut}
    end
  end
end
