defmodule FraytElixir.CustomContracts.TileShopSameDay do
  alias FraytElixir.CustomContracts.{Contract, ContractFees, DistanceTemplate}

  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :vehicle_class,
    fees: [
      load_fee: %{
        250 => {24_99, 18_74},
        1001 => {44_99, 33_74},
        2001 => {99_99, 74_99}
      },
      lift_gate_fee: {30_00, 22_50},
      route_surcharge: {40_00, 0},
      toll_fees: true,
      return_charge: 0.5,
      preferred_driver_fee: ContractFees.default_preferred_driver_fee_percentage()
    ],
    markups: [
      time_surcharge: [
        {{~T[15:30:00], ~T[06:00:00]}, 1.15},
        weekends: 1.15,
        holidays: 1.15
      ]
    ],
    tiers: [
      car: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 20_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 200,
          max_volume: 28,
          per_mile_tapering: %{
            50 => 1_35,
            150 => 1_08
          }
        }
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 25_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 500,
          max_volume: 45,
          per_mile_tapering: %{
            50 => 1_70,
            150 => 1_36
          }
        }
      },
      cargo_van: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 44_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 3500,
          max_volume: 140,
          per_mile_tapering: %{
            50 => 2_25,
            150 => 1_80
          }
        }
      },
      box_truck: %LevelTier{
        first: %DistanceTier{
          price_per_mile: nil,
          base_price: 180_00,
          base_distance: 0,
          driver_cut: 0.75,
          max_weight: 10000,
          max_volume: 400,
          per_mile_tapering: %{
            75 => 3_00,
            100 => 4_60,
            125 => 3_90,
            200 => 2_00,
            500 => 2_50
          }
        },
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 40_00,
          base_distance: 0,
          driver_cut: 0.75,
          max_weight: 10000,
          max_volume: 400,
          per_mile_tapering: %{
            75 => 3_00,
            100 => 4_60,
            125 => 3_90,
            200 => 2_00,
            500 => 2_50
          }
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
