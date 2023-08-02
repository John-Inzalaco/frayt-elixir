defmodule FraytElixir.CustomContracts.Roti do
  alias FraytElixir.CustomContracts.{DistanceTemplate, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}
  use Contract

  @default %DistanceTier{
    price_per_mile: 1_50,
    base_price: 25_00,
    markup: 1.0,
    max_weight: 20,
    base_distance: 5,
    driver_cut: 0.75,
    default_tip: 2_00
  }

  @config %DistanceTemplate{
    level_type: :none,
    tiers: [
      %LevelTier{
        first: @default,
        default: %{@default | base_price: 15_00, default_tip: 0}
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
