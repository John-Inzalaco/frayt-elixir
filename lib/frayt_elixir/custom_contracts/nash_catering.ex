defmodule FraytElixir.CustomContracts.NashCatering do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}
  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @default %DistanceTier{
    price_per_mile: 1_50,
    base_price: 20_00,
    markup: 1.00,
    base_distance: 10,
    driver_cut: 0.75
  }

  @config %DistanceTemplate{
    level_type: :distance,
    distance_type: :radius_from_origin,
    tiers: [
      %LevelTier{
        first: %{@default | base_price: 30_00, price_per_mile: 1_50},
        default: @default
      }
    ],
    fees: [
      toll_fees: true
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
