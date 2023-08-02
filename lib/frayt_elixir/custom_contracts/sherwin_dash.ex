defmodule FraytElixir.CustomContracts.SherwinDash do
  alias FraytElixir.CustomContracts.{DistanceTemplate, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}

  use Contract

  @base_config %DistanceTemplate{
    level_type: :vehicle_class,
    distance_type: :radius_from_origin,
    markups: [
      time_surcharge: [
        {{~T[18:00:00], ~T[06:00:00]}, 1.15},
        weekends: 1.15,
        holidays: 1.2
      ]
    ],
    fees: [
      return_charge: 0.50,
      load_fee: %{
        250 => {24_99, 18_74},
        1_001 => {44_99, 33_74},
        2_001 => {99_99, 74_99}
      },
      lift_gate_fee: {30_00, 22_50},
      toll_fees: true
    ],
    tiers: []
  }

  def base_config(), do: @base_config

  @config %{
    @base_config
    | tiers: [
        car: %LevelTier{
          default: %DistanceTier{
            base_price: 22_50,
            price_per_mile: 1_50,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 100,
            max_volume: 28
          }
        },
        midsize: %LevelTier{
          default: %DistanceTier{
            base_price: 30_00,
            price_per_mile: 1_85,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 250,
            max_volume: 45
          }
        },
        cargo_van: %LevelTier{
          default: %DistanceTier{
            base_price: 48_00,
            price_per_mile: 2_50,
            base_distance: 10,
            driver_cut: 0.8,
            max_weight: 3_000,
            max_volume: 150
          }
        }
      ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
