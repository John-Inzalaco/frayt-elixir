defmodule FraytElixir.CustomContracts.ShareBite do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}
  alias DistanceTemplate.{LevelTier, DistanceTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :distance,
    tiers: [
      %LevelTier{
        first: %DistanceTier{
          base_price: 30_00,
          price_per_mile: 1_50,
          base_distance: 10,
          driver_cut: 0.75
        },
        default: %DistanceTier{
          base_price: 15_00,
          price_per_mile: 1_50,
          base_distance: 5,
          driver_cut: 0.75
        }
      }
    ],
    markups: [
      state: %{
        "WA" => 7 / 6,
        "IL" => 7 / 6,
        "NY" => 7 / 6,
        "CA" => 7 / 6
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
