defmodule FraytElixir.CustomContracts.Default do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}
  alias DistanceTemplate.{LevelTier, DistanceTier}
  alias FraytElixir.CustomContracts.ContractFees
  use Contract

  @fees [
    load_fee: %{
      250 => {24_99, 18_74},
      1000 => {44_99, 33_74},
      2000 => {99_99, 74_99},
      3000 => {144_99, 108_74}
    },
    route_surcharge: {50, 0},
    holiday_fee: {100_00, 75_00},
    lift_gate_fee: {30_00, 22_50},
    preferred_driver_fee: ContractFees.default_preferred_driver_fee_percentage(),
    toll_fees: true
  ]

  @markups [
    market: true,
    time_surcharge: [
      {{~T[15:30:00], ~T[07:00:00]}, 1.2},
      weekends: 1.3
    ]
  ]

  def fees, do: @fees
  def markups, do: @markups

  @dash %DistanceTemplate{
    level_type: :vehicle_class,
    fees: @fees,
    markups: @markups,
    tiers: [
      car: %LevelTier{
        default: %DistanceTier{
          base_price: 12_60,
          price_per_mile: 1_25,
          base_distance: 5,
          driver_cut: 0.72
        },
        first:
          {1,
           %DistanceTier{
             base_price: 28_34,
             price_per_mile: 1_02,
             base_distance: 10,
             driver_cut: 0.72,
             per_mile_tapering: %{
               50 => 1_60,
               150 => 1_28
             }
           }}
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          base_price: 14_70,
          price_per_mile: 1_50,
          base_distance: 5,
          driver_cut: 0.72
        },
        first:
          {1,
           %DistanceTier{
             base_price: 38_84,
             price_per_mile: 1_22,
             base_distance: 10,
             driver_cut: 0.72,
             per_mile_tapering: %{
               50 => 1_90,
               150 => 1_52
             }
           }}
      },
      cargo_van: %LevelTier{
        default: %DistanceTier{
          base_price: 18_90,
          price_per_mile: 2_00,
          base_distance: 5,
          driver_cut: 0.72
        },
        first:
          {1,
           %DistanceTier{
             base_price: 58_79,
             price_per_mile: 1_63,
             base_distance: 10,
             driver_cut: 0.72,
             per_mile_tapering: %{
               50 => 2_55,
               150 => 2_04
             }
           }}
      },
      box_truck: %LevelTier{
        default: %DistanceTier{
          price_per_mile: 1_20,
          base_price: 26_25,
          base_distance: 5,
          driver_cut: 0.8,
          per_mile_tapering: %{
            75 => 3_00,
            100 => 4_60,
            125 => 3_90,
            200 => 2_00,
            500 => 1_50,
            1_000 => 2_00,
            1_200 => 1_50
          }
        },
        first:
          {1,
           %DistanceTier{
             price_per_mile: 1_20,
             base_price: 200_00,
             base_distance: 0,
             driver_cut: 0.8,
             per_mile_tapering: %{
               75 => 3_00,
               100 => 4_60,
               125 => 3_90,
               200 => 2_00,
               500 => 1_50,
               1_000 => 2_00,
               1_200 => 1_50
             }
           }}
      }
    ]
  }

  @same_day %DistanceTemplate{
    level_type: :vehicle_class,
    fees: @fees,
    markups: @markups,
    tiers: [
      car: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 10_08,
          base_distance: 5,
          driver_cut: 0.72,
          per_mile_tapering: %{
            100 => 1_00
          }
        },
        first:
          {1,
           %DistanceTier{
             price_per_mile: nil,
             base_price: 22_67,
             base_distance: 10,
             driver_cut: 0.72,
             per_mile_tapering: %{
               50 => 1_28,
               100 => 1_02
             }
           }}
      },
      midsize: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 11_76,
          base_distance: 5,
          driver_cut: 0.72,
          per_mile_tapering: %{
            100 => 1_20
          }
        },
        first:
          {1,
           %DistanceTier{
             price_per_mile: nil,
             base_price: 31_07,
             base_distance: 10,
             driver_cut: 0.72,
             per_mile_tapering: %{
               50 => 1_52,
               100 => 1_22
             }
           }}
      },
      cargo_van: %LevelTier{
        default: %DistanceTier{
          price_per_mile: nil,
          base_price: 15_12,
          base_distance: 5,
          driver_cut: 0.72,
          per_mile_tapering: %{
            100 => 1_60
          }
        },
        first:
          {1,
           %DistanceTier{
             price_per_mile: nil,
             base_price: 47_03,
             base_distance: 10,
             driver_cut: 0.72,
             per_mile_tapering: %{
               50 => 2_04,
               100 => 1_63
             }
           }}
      }
    ]
  }

  @impl true
  def calculate_pricing(match) do
    config = get_template_config(match)

    DistanceTemplate.calculate_pricing(match, config)
  end

  def include_tolls?(match) do
    config = get_template_config(match)

    DistanceTemplate.include_tolls?(match, config)
  end

  defp get_template_config(match) do
    case match.service_level do
      1 -> @dash
      2 -> @same_day
    end
  end
end
