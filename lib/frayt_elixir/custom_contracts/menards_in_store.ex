defmodule FraytElixir.CustomContracts.MenardsInStore do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}

  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :distance,
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          base_price: 69_00,
          base_distance: 15,
          driver_cut: 0.75
        }
      },
      %LevelTier{
        default: %DistanceTier{
          base_price: 89_00,
          base_distance: 25,
          driver_cut: 0.75
        }
      },
      %LevelTier{
        default: %DistanceTier{
          price_per_mile: 200,
          base_price: 109_00,
          base_distance: 35,
          driver_cut: 0.75
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
