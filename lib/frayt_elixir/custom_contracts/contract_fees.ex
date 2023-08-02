defmodule FraytElixir.CustomContracts.ContractFees do
  alias FraytElixir.Repo
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Shipment
  alias Shipment.MatchFee
  alias FraytElixir.Markets.Market
  alias FraytElixir.Accounts.{Shipper, Company, Location}

  defstruct [:final, :initial]

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def calculate_fees(match, attrs, config_fees) do
    %{
      total_base_fee: total_base_fee,
      driver_tips: driver_tips,
      total_driver_base: total_driver_base
    } = attrs

    fees =
      Enum.map(config_fees, fn {fee_type, params_or_func} ->
        if is_function(params_or_func) do
          params_or_func.(fee_type, match)
        else
          calculate_fee(fee_type, match, params_or_func)
        end
      end)

    subtotal = sum_fees(fees, :amount) + total_base_fee + driver_tips
    driver_fees = calculate_driver_fees(match, subtotal)

    fees =
      Enum.reduce(config_fees, [], fn {fee_type, percentage}, acc ->
        attrs = Map.put(attrs, :driver_fees, driver_fees)

        case {fee_type, percentage} do
          {:return_charge, percentage} ->
            acc ++ [calculate_return_charge_fee(match, percentage, attrs)]

          {:preferred_driver_fee, percentage} ->
            acc ++ [calculate_preferred_driver_fee(match, percentage, attrs)]

          _ ->
            acc
        end
      end)
      |> then(&(fees ++ [&1]))
      |> List.flatten()

    fees =
      build_fees(
        match,
        [
          add_fee(:base_fee, total_base_fee, floor(total_driver_base - driver_fees)),
          add_fee(:driver_tip, driver_tips, driver_tips)
        ] ++ fees
      )

    {driver_fees, fees}
  end

  defp sum_fees(%Match{fees: fees}, field), do: sum_fees(fees, field)

  defp sum_fees(fees, field) when is_list(fees) and field in [:amount, :driver_amount] do
    fees
    |> Enum.filter(& &1)
    |> Enum.reduce(0, fn fee, total -> total + Map.get(fee, field, 0) end)
  end

  def calculate_driver_fees(%Match{fees: fees} = match) do
    amount = sum_fees(fees, :amount)
    calculate_driver_fees(match, amount)
  end

  def calculate_driver_fees(%Match{} = match, amount) do
    case Repo.preload(match, shipper: [location: :company]) do
      %Match{
        shipper: %Shipper{
          location: %Location{company: %Company{account_billing_enabled: true}}
        }
      } ->
        0

      _ ->
        ceil(amount * 0.029 + 30)
    end
  end

  defp calculate_fee(fee_type, match, params)

  defp calculate_fee(:route_surcharge, %{match_stops: stops}, params) when length(stops) > 1 do
    {amount, driver_amount} = params

    %{
      type: :route_surcharge,
      amount: amount,
      driver_amount: driver_amount
    }
  end

  defp calculate_fee(:holiday_fee, %{vehicle_class: 4} = match, params) do
    {amount, driver_amount} = params

    case Shipment.get_match_holidays(match) do
      {:ok, []} ->
        nil

      {:ok, holidays} ->
        %{
          type: :holiday_fee,
          amount: amount,
          driver_amount: driver_amount,
          description: Enum.map_join(holidays, ", ", & &1.name)
        }

      _ ->
        nil
    end
  end

  defp calculate_fee(:lift_gate_fee, %{unload_method: :lift_gate}, params) do
    {amount, driver_amount} = params

    %{
      type: :lift_gate_fee,
      amount: amount,
      driver_amount: driver_amount
    }
  end

  defp calculate_fee(:load_fee, match, params), do: calculate_load_fee(match, params)

  defp calculate_fee(
         :toll_fees,
         %Match{expected_toll: expected_toll, market: %Market{calculate_tolls: true}},
         true
       ),
       do: calculate_toll_fee_price(expected_toll)

  defp calculate_fee(:item_handling_fee, match, params), do: calculate_handling_fee(match, params)

  defp calculate_fee(:item_weight_fee, match, params),
    do: calculate_item_weight_fee(match, params)

  defp calculate_fee(_fee_type, _match, _params), do: nil

  defp calculate_preferred_driver_fee(%{preferred_driver_id: nil}, _percentage, _attrs),
    do: []

  defp calculate_preferred_driver_fee(match, percentage, attrs) do
    match = apply_changes_to_match(match, attrs)

    {amount, _} =
      Enum.reduce(match.match_stops, {0, 0}, fn stop, {shipper_total, driver_total} ->
        {shipper_total + stop.base_price, driver_total + stop.base_price * stop.driver_cut}
      end)

    preferred_driver_fee = amount * percentage

    %{
      type: :preferred_driver_fee,
      amount: round(preferred_driver_fee),
      driver_amount: round(preferred_driver_fee / 2),
      description: "Preferred driver charge"
    }
  end

  defp calculate_return_charge_fee(match, percentage, attrs) do
    match = apply_changes_to_match(match, attrs)

    undeliverable_stops = Enum.filter(match.match_stops, &(&1.state == :returned))

    if length(undeliverable_stops) > 0 do
      {amount, driver_amount} =
        Enum.reduce(undeliverable_stops, {0, 0}, fn stop, {shipper_total, driver_total} ->
          amount = stop.base_price * percentage
          {shipper_total + amount, driver_total + amount * stop.driver_cut}
        end)

      stop_count = Enum.count(undeliverable_stops)

      %{
        type: :return_charge,
        amount: round(amount),
        driver_amount: round(driver_amount),
        description: "#{stop_count} stops were returned"
      }
    end
  end

  defp apply_changes_to_match(match, attrs) do
    match
    |> Match.pricing_changeset(attrs)
    |> Ecto.Changeset.apply_changes()
  end

  defp calculate_load_fee(%Match{match_stops: stops}, weight_tiers) do
    load_weight =
      stops
      |> Enum.filter(& &1.has_load_fee)
      |> Enum.reduce(0, fn stop, acc ->
        count =
          stop.items
          |> Enum.filter(&(&1.type == :item))
          |> Enum.reduce(0, &(&1.pieces * &1.weight + &2))

        count + acc
      end)

    weight_tier =
      weight_tiers
      |> Enum.sort_by(fn {weight, _} -> weight end, :desc)
      |> Enum.find(fn {weight, _} -> load_weight >= weight end)

    case weight_tier do
      {_weight, {amount, driver_amount}} when amount > 0 ->
        %{
          amount: amount,
          driver_amount: driver_amount,
          type: :load_fee,
          description: "#{load_weight} lbs"
        }

      _ ->
        nil
    end
  end

  defp calculate_handling_fee(%Match{match_stops: stops}, fee_types) do
    handling_fee =
      stops
      |> Enum.map(&calc_stop_handling_fees(&1, fee_types))
      |> Enum.sum()

    %{
      amount: round(handling_fee),
      driver_amount: round(handling_fee),
      type: :handling_fee
    }
  end

  def calc_stop_handling_fees(stop, fee_types) do
    stop.items
    |> Enum.map(&calc_item_handling_fee(&1, fee_types))
    |> Enum.sum()
  end

  defp calc_item_handling_fee(item, fee_types) do
    case Keyword.fetch(fee_types, item.type) do
      {:ok, amount} -> amount * item.pieces
      :error -> 0
    end
  end

  defp calculate_toll_fee_price(amount) when is_integer(amount) and amount > 0 do
    %{
      type: :toll_fees,
      amount: amount,
      driver_amount: amount
    }
  end

  defp calculate_toll_fee_price(_amount), do: nil

  defp calculate_item_weight_fee(%Match{match_stops: stops}, weight_tiers) do
    highest_weight =
      stops
      |> Enum.flat_map(& &1.items)
      |> Enum.map(& &1.weight)
      |> Enum.max(fn -> 0 end)

    fee =
      weight_tiers
      |> Enum.sort_by(fn {weight, _} -> weight end, :desc)
      |> Enum.find_value(fn {weight, fee} -> if highest_weight >= weight, do: fee end)

    if fee, do: %{type: :item_weight_fee, amount: fee, driver_amount: fee}
  end

  def build_fees(match, fees) do
    fees
    |> Enum.filter(& &1)
    |> Enum.map(&build_fee(match, &1))
  end

  def build_fee(%Match{fees: fees}, %{type: fee_type} = attrs) do
    fee =
      fees
      |> Enum.find(&(&1.type == fee_type))

    case fee do
      nil ->
        attrs

      %MatchFee{id: fee_id} ->
        attrs |> Map.put(:id, fee_id)
    end
  end

  defp add_fee(type, amount, driver_amount) when amount != 0 or driver_amount != 0,
    do: %{
      type: type,
      amount: amount,
      driver_amount: driver_amount
    }

  defp add_fee(_type, _amount, _driver_amount), do: nil

  def default_preferred_driver_fee_percentage,
    do: get_config(:default_preferred_driver_fee) |> String.to_float()
end
