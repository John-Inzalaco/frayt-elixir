defmodule FraytElixir.CustomContracts.AxleHireDentonDallas do
  alias FraytElixir.CustomContracts.{Contract, DistanceTemplate}
  alias DistanceTemplate.{DistanceTier, LevelTier}

  use Contract

  @default %DistanceTier{
    price_per_mile: 0,
    base_price: 65_00,
    markup: 1.00,
    base_distance: nil,
    driver_cut: 0.732
  }

  @config %DistanceTemplate{
    level_type: :scheduled,
    tiers: [
      dash: %LevelTier{
        first: %{@default | base_distance: 0},
        default: @default
      },
      scheduled: %LevelTier{
        first: %{@default | base_distance: 0},
        default: @default
      }
    ]
  }

  @impl true
  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
