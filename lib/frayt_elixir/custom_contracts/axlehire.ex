defmodule FraytElixir.CustomContracts.AxleHire do
  alias FraytElixir.CustomContracts.{DistanceTemplate, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}
  use Contract

  @car_default %DistanceTier{
    price_per_mile: nil,
    base_price: 26_93,
    base_distance: 9,
    driver_cut: 0.75,
    per_mile_tapering: %{
      50 => 1_60,
      150 => 1_28
    }
  }

  @midsize_default %DistanceTier{
    price_per_mile: nil,
    base_price: 36_90,
    base_distance: 9,
    driver_cut: 0.75,
    per_mile_tapering: %{
      50 => 1_90,
      150 => 1_52
    }
  }

  @cargo_default %DistanceTier{
    price_per_mile: nil,
    base_price: 55_85,
    base_distance: 9,
    driver_cut: 0.75,
    per_mile_tapering: %{
      50 => 2_55,
      150 => 2_04
    }
  }

  @config %DistanceTemplate{
    level_type: :vehicle_class,
    distance_type: :radius_from_origin,
    tiers: [
      car: %LevelTier{
        first: @car_default,
        default: %{
          @car_default
          | base_price: 10_00,
            price_per_mile: 1_25,
            per_mile_tapering: %{}
        }
      },
      midsize: %LevelTier{
        first: @midsize_default,
        default: %{
          @midsize_default
          | base_price: 12_00,
            price_per_mile: 1_50,
            per_mile_tapering: %{}
        }
      },
      cargo_van: %LevelTier{
        first: @cargo_default,
        default: %{
          @cargo_default
          | base_price: 15_00,
            price_per_mile: 2_00,
            per_mile_tapering: %{}
        }
      }
    ],
    fees: [
      load_fee: %{
        101 => {15_00, 11_25},
        251 => {20_00, 15_00},
        1001 => {40_00, 30_00}
      },
      route_surcharge: {0_50, 0},
      toll_fees: true
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
