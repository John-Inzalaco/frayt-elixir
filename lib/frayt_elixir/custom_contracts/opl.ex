defmodule FraytElixir.CustomContracts.OPL do
  alias FraytElixir.CustomContracts.{DistanceTemplate, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :vehicle_class,
    tiers: [
      car: %LevelTier{
        default: %DistanceTier{
          price_per_mile: 1_50,
          base_price: 10_00,
          base_distance: 0,
          driver_cut: 0.75
        }
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          price_per_mile: 1_50,
          base_price: 10_00,
          base_distance: 0,
          driver_cut: 0.75
        }
      },
      cargo_van: %LevelTier{
        default: %DistanceTier{
          price_per_mile: 1_85,
          base_price: 10_00,
          base_distance: 0,
          driver_cut: 0.75
        }
      },
      box_truck: %LevelTier{
        default: %DistanceTier{
          price_per_mile: 2_35,
          base_price: 10_00,
          base_distance: 0,
          driver_cut: 0.75
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
