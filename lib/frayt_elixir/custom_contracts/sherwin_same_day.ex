defmodule FraytElixir.CustomContracts.SherwinSameDay do
  alias FraytElixir.CustomContracts.{DistanceTemplate, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}
  alias FraytElixir.CustomContracts.SherwinDash

  use Contract

  @config %{
    SherwinDash.base_config()
    | tiers: [
        car: %LevelTier{
          default: %DistanceTier{
            base_price: 18_00,
            price_per_mile: 1_28,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 100,
            max_volume: 28
          }
        },
        midsize: %LevelTier{
          default: %DistanceTier{
            base_price: 23_00,
            price_per_mile: 1_52,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 250,
            max_volume: 45
          }
        },
        cargo_van: %LevelTier{
          default: %DistanceTier{
            base_price: 40_00,
            price_per_mile: 2_04,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 3_000,
            max_volume: 150
          }
        },
        box_truck: %LevelTier{
          first: %DistanceTier{
            base_price: 200_00,
            price_per_mile: 3_00,
            base_distance: 0,
            driver_cut: 0.8,
            max_weight: 10_000,
            max_volume: 400
          },
          default: %DistanceTier{
            base_price: 40_00,
            price_per_mile: 3_00,
            base_distance: 0,
            driver_cut: 0.8,
            max_weight: 10_000,
            max_volume: 400
          }
        }
      ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
