defmodule FraytElixir.CustomContracts.LocalFavorite do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}

  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :none,
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          price_per_mile: 1_50,
          base_price: 30_00,
          base_distance: 10,
          driver_cut: 0.75,
          cargo_value_cut: 0.1
        }
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
