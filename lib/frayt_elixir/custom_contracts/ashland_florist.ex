defmodule FraytElixir.CustomContracts.AshlandFlorist do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}
  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :distance,
    distance_type: :radius_from_origin,
    markups: [
      time_surcharge: [
        {{~T[15:30:00], ~T[07:00:00]}, 1.15},
        weekends: 1.15
      ]
    ],
    fees: [
      return_charge: 0.5,
      toll_fees: true
    ],
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          base_price: 10_00,
          base_distance: 3,
          driver_cut: 0.75,
          max_item_weight: 50
        }
      },
      %LevelTier{
        default: %DistanceTier{
          base_price: 12_50,
          base_distance: 10,
          driver_cut: 0.75,
          max_item_weight: 50
        }
      },
      %LevelTier{
        default: %DistanceTier{
          price_per_mile: 1_50,
          base_price: 16_00,
          base_distance: 15,
          driver_cut: 0.75,
          max_item_weight: 50
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
