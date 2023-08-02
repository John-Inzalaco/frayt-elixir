defmodule FraytElixir.Shipment.Pricing do
  import Ecto.Query, warn: false
  import FraytElixir.Guards
  require Logger
  alias Ecto.Changeset
  alias FraytElixir.{Shipment, Repo, CustomContracts}
  alias FraytElixir.Convert
  alias FraytElixir.TollGuru
  alias FraytElixir.Notifications.Slack

  alias Shipment.{
    Coupon,
    ShipperMatchCoupon,
    Match
  }

  def calculate_driver_total_pay(match),
    do: sum_fees(match, :driver_amount)

  def total_price(match) do
    subtotal = subtotal(match)
    driver_tip = Shipment.get_match_fee_price(match, :driver_tip, :shipper) || 0

    with base_price when not is_nil(base_price) <-
           Shipment.get_match_fee_price(match, :base_fee, :shipper),
         shipper_match_coupon <- get_shipper_match_coupon_by_match(match),
         %{coupon: coupon} <- shipper_match_coupon |> Repo.preload(:coupon),
         price_discount <- calculate_discount(coupon, subtotal - driver_tip) do
      {subtotal -
         price_discount, price_discount}
    else
      _ -> {subtotal, 0}
    end
    |> integer_prices()
  end

  defp calculate_discount(
         %Coupon{percentage: percentage, discount_maximum: discount_maximum},
         price
       ),
       do: min(percentage * price * 0.01, discount_maximum)

  def convert_price(value) when is_binary(value) do
    value |> Convert.to_float() |> Kernel.*(100) |> round()
  end

  def convert_price(value) when is_integer(value), do: value
  def convert_price(_value), do: 0

  defp integer_prices({total, discount}), do: {Kernel.ceil(total), Kernel.ceil(discount)}

  def subtotal(match), do: sum_fees(match, :amount)

  defp sum_fees(%Match{fees: fees}, field), do: sum_fees(fees, field)

  defp sum_fees(fees, field) when is_list(fees) and field in [:amount, :driver_amount] do
    fees
    |> Enum.filter(& &1)
    |> Enum.reduce(0, fn fee, total -> total + Map.get(fee, field, 0) end)
  end

  def apply_coupon_changeset(match, code) when is_empty(code),
    do: Match.coupon_changeset(match, %{shipper_match_coupon: nil})

  def apply_coupon_changeset(match, code) when not is_empty(code) do
    coupon = get_coupon_by_code(code)
    match = match |> Repo.preload(:shipper_match_coupon)
    attrs = shipper_match_coupon_attrs(match, coupon)

    Match.coupon_changeset(match, %{shipper_match_coupon: attrs})
  end

  def get_coupon_by_code(nil), do: nil

  def get_coupon_by_code(code) do
    code = code |> String.trim()

    query =
      from(c in Coupon,
        where: ilike(c.code, ^code),
        limit: 1
      )

    Repo.one(query)
  end

  def get_coupon!(id), do: Repo.get!(Coupon, id)

  def create_coupon(attrs) do
    %Coupon{}
    |> Coupon.changeset(attrs)
    |> Repo.insert()
  end

  def get_shipper_match_coupon_by_match(match) do
    query =
      ShipperMatchCoupon
      |> ShipperMatchCoupon.where_shipper_is(match.shipper_id)
      |> ShipperMatchCoupon.where_match_is(match.id)

    Repo.one(query)
  end

  def validate_match_coupon(match) do
    match = match |> Repo.preload([:coupon, :shipper_match_coupon])

    if match.shipper_match_coupon do
      match.shipper_match_coupon
      |> ShipperMatchCoupon.changeset(%{}, match, match.coupon)
      |> case do
        %{valid?: true} -> {:ok, match.coupon}
        %{valid?: false} = changeset -> {:error, changeset}
      end
    else
      {:ok, nil}
    end
  end

  def shipper_match_coupon_attrs(match, %Coupon{} = coupon),
    do: %{
      match_id: match.id,
      shipper_id: match.shipper_id,
      coupon_id: coupon.id,
      id: Map.get(match.shipper_match_coupon || %{}, :id)
    }

  def shipper_match_coupon_attrs(match, _),
    do: %{match_id: match.id, shipper_id: match.shipper_id, coupon_id: nil}

  def calculate_pricing(match) do
    CustomContracts.calculate_pricing(match)
    |> Changeset.validate_required([
      :driver_cut
    ])
  end

  def build_pricing(match, stop_calculator_fn, fee_calculator_fn) do
    %Match{match_stops: stops} = match

    {{total_base_fee, driver_tips, total_driver_base}, stops_attrs, errors} =
      Enum.reduce(stops, {{0, 0, 0}, [], []}, fn stop,
                                                 {{total_base_fee, total_tip, total_driver_base} =
                                                    totals, stop_attrs, errors} ->
        case stop_calculator_fn.(stop, match) do
          {:ok,
           %{
             base_price: base_price,
             driver_cut: driver_cut,
             tip_price: tip_price
           }} ->
            {{total_base_fee + base_price, total_tip + tip_price,
              total_driver_base + base_price * driver_cut},
             stop_attrs ++
               [
                 %{
                   id: stop.id,
                   base_price: base_price,
                   tip_price: tip_price,
                   driver_cut: driver_cut
                 }
               ], errors}

          {:error, field, message, meta} ->
            {totals, stop_attrs, errors ++ [{stop.id, field, message, meta}]}
        end
      end)

    if Enum.empty?(errors) do
      driver_cut =
        total_driver_base
        |> Decimal.from_float()
        |> Decimal.div(total_base_fee)
        |> Decimal.to_float()

      attrs = %{
        total_base_fee: total_base_fee,
        driver_tips: driver_tips,
        total_driver_base: total_driver_base,
        driver_cut: driver_cut,
        match_stops: stops_attrs
      }

      {driver_fees, fees} = fee_calculator_fn.(match, attrs)

      {:ok,
       %{
         fees: fees,
         driver_fees: driver_fees,
         driver_cut: driver_cut,
         match_stops: stops_attrs
       }}
    else
      {:error, errors}
    end
  end

  def apply_errors(match, errors) do
    changeset = Changeset.cast(match, %{}, [])

    Enum.reduce(errors, changeset, &apply_error(&2, &1))
  end

  defp apply_error(changeset, {_stop_id, {:match, field}, message, meta}),
    do: Changeset.add_error(changeset, field, message, meta)

  defp apply_error(changeset, {stop_id, field, message, meta}) do
    stops =
      changeset
      |> Changeset.get_field(:match_stops)
      |> Enum.map(fn stop ->
        if stop.id == stop_id do
          stop
          |> Changeset.cast(%{}, [])
          |> Changeset.add_error(field, message, meta)
        end
      end)
      |> Enum.filter(& &1)

    Changeset.put_change(changeset, :match_stops, stops)
  end

  def calculate_expected_toll(%Match{match_stops: stops}) when stops == [], do: {:ok, 0}

  def calculate_expected_toll(
        %Match{
          origin_address: origin_address,
          match_stops: stops,
          id: id
        } = match
      ) do
    {destination_stop, waypoint_stops} = List.pop_at(stops, -1)

    attrs = %{
      from: %{address: origin_address.formatted_address},
      to: %{address: destination_stop.destination_address.formatted_address},
      waypoints:
        Enum.map(waypoint_stops, fn s -> %{address: s.destination_address.formatted_address} end),
      departure_time: Shipment.match_departure_time(match),
      vehicleType: "2AxlesAuto",
      units: %{currencyUnit: "USD"}
    }

    case TollGuru.calculate_toll(attrs) do
      {:ok, %{"routes" => routes}} ->
        route =
          Enum.find(routes, List.first(routes), fn r ->
            get_in(r, ~w(summary diffs fastest)) == 0
          end)

        case get_in(route, ~w(summary hasTolls)) do
          true ->
            amount =
              route
              |> Map.get("costs")
              |> Map.take(~w(tag cash licensePlate creditCard prepaidCard))
              |> Map.values()
              |> Enum.map(&(&1 || 0))
              |> Enum.max()
              |> (fn t -> round(t * 100) end).()

            {:ok, amount}

          false ->
            {:ok, 0}
        end

      error ->
        error_message = inspect(error) |> String.slice(0..2048)

        error_log =
          "An error occurred calculating tolls for Match #{id}: \n```\n#{error_message}\n```"

        Slack.send_message(:errors, error_log)

        Logger.error(error_log)

        {:ok, 0}
    end
  end
end
