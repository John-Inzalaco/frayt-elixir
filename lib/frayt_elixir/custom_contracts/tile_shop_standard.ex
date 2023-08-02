defmodule FraytElixir.CustomContracts.TileShopStandard do
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
          base_price: 23_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 200,
          max_volume: 28,
          per_mile_tapering: %{
            50 => 1_60,
            150 => 1_28
          }
        }
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 30_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 500,
          max_volume: 45,
          per_mile_tapering: %{
            50 => 1_90,
            150 => 1_52
          }
        }
      },
      cargo_van: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 48_00,
          base_distance: 10,
          driver_cut: 0.75,
          max_weight: 3500,
          max_volume: 140,
          per_mile_tapering: %{
            50 => 2_55,
            150 => 2_04
          }
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
