defmodule FraytElixir.CustomContracts.Walmart do
  alias FraytElixir.CustomContracts.Contract
  alias FraytElixir.CustomContracts.DistanceTemplate
  alias DistanceTemplate.{LevelTier, DistanceTier}
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match

  use Contract

  def get_config(),
    do: %DistanceTemplate{
      distance_type: :radius_from_origin,
      level_type: :weight,
      markups: [state: %{"NY" => 1.2, "CA" => 1.2}],
      fees: [
        return_charge: 0.50,
        item_weight_fee: %{75 => 15_00},
        priority_fee: &calculate_priority_fee/2
      ],
      tiers: [
        {
          100,
          %LevelTier{
            first: %DistanceTier{
              base_price: 18_00,
              price_per_mile: 1_00,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 15_00,
              price_per_mile: 1_00,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          200,
          %LevelTier{
            first: %DistanceTier{
              base_price: 20_00,
              price_per_mile: 1_00,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 15_00,
              price_per_mile: 1_00,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          300,
          %LevelTier{
            first: %DistanceTier{
              base_price: 25_00,
              price_per_mile: 1_05,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 15_00,
              price_per_mile: 1_05,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          500,
          %LevelTier{
            first: %DistanceTier{
              base_price: 50_00,
              price_per_mile: 1_20,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 25_00,
              price_per_mile: 1_20,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          1000,
          %LevelTier{
            first: %DistanceTier{
              base_price: 75_00,
              price_per_mile: 1_35,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 35_00,
              price_per_mile: 1_35,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          2000,
          %LevelTier{
            first: %DistanceTier{
              base_price: 100_00,
              price_per_mile: 1_75,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 50_00,
              price_per_mile: 1_75,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          3000,
          %LevelTier{
            first: %DistanceTier{
              base_price: 150_00,
              price_per_mile: 2_50,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 50_00,
              price_per_mile: 2_50,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        },
        {
          8000,
          %LevelTier{
            first: %DistanceTier{
              base_price: 250_00,
              price_per_mile: 2_50,
              base_distance: 10,
              driver_cut: 0.75,
              max_item_weight: 250
            },
            default: %DistanceTier{
              base_price: 50_00,
              price_per_mile: 2_50,
              base_distance: 5,
              driver_cut: 0.75,
              max_item_weight: 250
            }
          }
        }
      ]
    }

  @impl true
  def calculate_pricing(match) do
    config = get_config()
    DistanceTemplate.calculate_pricing(match, config)
  end

  def include_tolls?(match) do
    config = get_config()

    DistanceTemplate.include_tolls?(match, config)
  end

  defp calculate_priority_fee(fee_type, match) do
    sla = get_sla(match)

    amount = get_priority_fee(sla, match.total_weight)

    %{
      type: fee_type,
      amount: amount,
      driver_amount: floor(amount * 0.75),
      description: "#{Phoenix.Naming.humanize(sla)} fee"
    }
  end

  defp get_sla(%Match{scheduled: true, dropoff_at: dropoff_at} = match)
       when not is_nil(dropoff_at) do
    authorized_at = Shipment.match_authorized_time(match) || NaiveDateTime.utc_now()

    hours_after = NaiveDateTime.diff(dropoff_at, authorized_at, :second) / 60 / 60

    cond do
      hours_after < 3 -> :on_demand
      hours_after < 4 -> :standard
      true -> :scheduled
    end
  end

  defp get_sla(_match), do: :on_demand

  defp get_priority_fee(:standard, _weight), do: 0

  defp get_priority_fee(:on_demand, weight) do
    cond do
      weight <= 300 -> 3_00
      weight <= 500 -> 5_00
      weight <= 1000 -> 10_00
      weight <= 2000 -> 15_00
      true -> 25_00
    end
  end

  defp get_priority_fee(:scheduled, weight) do
    cond do
      weight <= 200 -> -1_00
      weight <= 300 -> -2_00
      weight <= 500 -> -4_00
      weight <= 1000 -> -6_00
      weight <= 2000 -> -8_00
      true -> -12_00
    end
  end
end
