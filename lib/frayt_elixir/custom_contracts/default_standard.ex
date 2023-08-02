defmodule FraytElixir.CustomContracts.DefaultStandard do
  alias FraytElixir.CustomContracts.{Contract, Default, DistanceTemplate}

  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :vehicle_class,
    fees: Default.fees(),
    markups: Default.markups(),
    tiers: [
      car: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 23_95,
          base_distance: 10,
          driver_cut: 0.72,
          per_mile_tapering: %{
            50 => 1_35,
            100 => 1_08
          }
        }
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 31_95,
          base_distance: 10,
          driver_cut: 0.72,
          per_mile_tapering: %{
            50 => 1_70,
            100 => 1_36
          }
        }
      },
      cargo_van: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 49_95,
          base_distance: 10,
          driver_cut: 0.72,
          per_mile_tapering: %{
            50 => 2_25,
            100 => 1_80
          }
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
