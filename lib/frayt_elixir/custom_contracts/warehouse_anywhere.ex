defmodule FraytElixir.CustomContracts.WarehouseAnywhere do
  use FraytElixir.CustomContracts.Contract
  alias FraytElixir.CustomContracts.ContractFees
  alias FraytElixir.Shipment.{Match, MatchStop, Pricing}
  alias Ecto.Changeset

  @minimum_price 2500
  @price_per_mile 200
  @included_miles 10
  def calculate_pricing(match)

  def calculate_pricing(%Match{vehicle_class: vehicle_class} = match)
      when vehicle_class == 4,
      do:
        Match.pricing_changeset(match, %{})
        |> Changeset.add_error(:vehicle_class, "Box Truck are not supported in this contract")

  def calculate_pricing(%Match{total_distance: distance} = match) do
    {price, driver_cut} = calculate_price(distance)

    pricing_params = %{
      price: ceil(price),
      driver_cut: driver_cut
    }

    fee_fn = &ContractFees.calculate_fees(&1, &2, [])

    {:ok, attrs} =
      Pricing.build_pricing(match, &calculate_stop_pricing(&1, &2, pricing_params), fee_fn)

    match
    |> Match.pricing_changeset(attrs)
    |> validate_single_stop()
  end

  defp calculate_stop_pricing(%MatchStop{tip_price: tip_price}, _match, %{
         price: price,
         driver_cut: driver_cut
       }),
       do: {:ok, %{tip_price: tip_price, base_price: price, driver_cut: driver_cut}}

  defp calculate_price(distance) when distance <= @included_miles, do: {@minimum_price, 0.75}

  defp calculate_price(distance),
    do: {@minimum_price + (distance - @included_miles) * @price_per_mile, 0.75}
end
