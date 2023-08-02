defmodule FraytElixir.CustomContracts.Oberers do
  alias FraytElixir.Shipment.Match
  alias FraytElixir.CustomContracts.{DistanceTemplate, Default, Contract}
  alias DistanceTemplate.{LevelTier, DistanceTier}

  use Contract

  @car_default %DistanceTier{
    base_price: 12_00,
    price_per_mile: 1_60,
    base_distance: 5,
    driver_cut: 0.75
  }

  @midsize_default %DistanceTier{
    base_price: 12_00,
    price_per_mile: 1_60,
    base_distance: 5,
    driver_cut: 0.75
  }

  @config %DistanceTemplate{
    level_type: :vehicle_class,
    tiers: [
      car: %LevelTier{
        first: %{@car_default | base_distance: 20},
        default: @car_default
      },
      midsize: %LevelTier{
        first: %{@midsize_default | base_distance: 20},
        default: @midsize_default
      }
    ]
  }

  @impl true
  def calculate_pricing(%Match{match_stops: stops} = match) when length(stops) < 5,
    do: Default.calculate_pricing(match)

  def calculate_pricing(match), do: DistanceTemplate.calculate_pricing(match, @config)

  def include_tolls?(match), do: DistanceTemplate.include_tolls?(match, @config)
end
