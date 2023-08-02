defmodule FraytElixir.CustomContracts.Zeitlins do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}
  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @config %DistanceTemplate{
    level_type: :none,
    fees: [
      toll_fees: true
    ],
    tiers: [
      %LevelTier{
        default: %DistanceTier{
          base_price: 35_00,
          base_distance: nil,
          driver_cut: 0.75
        }
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
