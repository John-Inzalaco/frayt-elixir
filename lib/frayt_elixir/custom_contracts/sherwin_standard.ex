defmodule FraytElixir.CustomContracts.SherwinStandard do
  alias FraytElixir.CustomContracts.{DistanceTemplate, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}
  alias FraytElixir.CustomContracts.SherwinDash

  use Contract

  @config %{
    SherwinDash.base_config()
    | tiers: [
        car: %LevelTier{
          default: %DistanceTier{
            base_price: 21_00,
            price_per_mile: 1_35,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 100,
            max_volume: 28
          }
        },
        midsize: %LevelTier{
          default: %DistanceTier{
            base_price: 27_00,
            price_per_mile: 1_70,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 250,
            max_volume: 45
          }
        },
        cargo_van: %LevelTier{
          default: %DistanceTier{
            base_price: 43_00,
            price_per_mile: 2_25,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 3_000,
            max_volume: 150
          }
        }
      ]
  }

  def get_auto_configure_dropoff_at, do: {:ok, true}

  def get_auto_dropoff_at_time, do: {:ok, 14_400}

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
