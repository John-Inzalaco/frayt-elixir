defmodule FraytElixir.CustomContracts.TireAgent do
  use FraytElixir.CustomContracts.Contract
  alias Ecto.Changeset
  alias FraytElixir.Cache
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Address, Match, MatchStop, Pricing}
  alias FraytElixir.CustomContracts.ContractFees

  @included_miles 10

  @pricing %{
    car: %{
      tier1: %{
        base: 1499,
        additional: 100
      },
      tier2: %{
        base: 1600,
        additional: 125
      }
    },
    midsize: %{
      tier1: %{
        base: 2499,
        additional: 125
      },
      tier2: %{
        base: 2999,
        additional: 150
      }
    },
    cargo_van: %{
      tier1: %{
        base: 3499,
        additional: 150
      },
      tier2: %{
        base: 4199,
        additional: 180
      }
    }
  }

  def calculate_pricing(
        %Match{
          total_distance: distance,
          vehicle_class: vehicle_class,
          origin_address: %Address{zip: origin_zip}
        } = match
      ) do
    case calculate_price(distance, vehicle_class, tier(origin_zip)) do
      {:ok, price} ->
        pricing_params = %{
          price: ceil(price)
        }

        fee_fn = &ContractFees.calculate_fees(&1, &2, [])

        {:ok, attrs} =
          Pricing.build_pricing(match, &calculate_stop_pricing(&1, &2, pricing_params), fee_fn)

        match
        |> Match.pricing_changeset(attrs)
        |> validate_single_stop()

      {:error, code, msg} ->
        match
        |> Match.pricing_changeset(%{})
        |> Changeset.add_error(:vehicle_class, msg, validation: code)
    end
  end

  defp calculate_stop_pricing(%MatchStop{tip_price: tip_price}, _match, %{price: price}),
    do: {:ok, %{tip_price: tip_price, base_price: price, driver_cut: 0.75}}

  defp tier(zip) do
    case zip in tier2_zipcodes() do
      true -> :tier2
      _ -> :tier1
    end
  end

  defp tier2_zipcodes do
    case Cache.get({:tire_agent_cache, "tier2_zipcodes"}) do
      nil ->
        Path.join(:code.priv_dir(:frayt_elixir), "data/tire_agent_tier2_zipcodes.csv")
        |> File.stream!()
        |> CSV.decode!()
        |> Enum.to_list()
        |> List.flatten()

      zipcodes ->
        zipcodes
    end
  end

  defp calculate_price(distance, vehicle_class, tier) when is_number(vehicle_class),
    do: calculate_price(distance, Shipment.vehicle_classes(vehicle_class), tier)

  defp calculate_price(distance, vehicle_class, tier)
       when vehicle_class in [:car, :midsize, :cargo_van],
       do:
         calculate_price!(
           distance,
           @pricing[vehicle_class][tier].base,
           @pricing[vehicle_class][tier].additional
         )

  defp calculate_price(_, :box_truck, _),
    do: {:error, :no_box_truck, "Box Truck are not supported in this contract"}

  defp calculate_price(_, _, _), do: {:error, :is_valid_vehicle, "Invalid Vehicle Class"}

  defp calculate_price!(distance, base_price, _additional_price)
       when distance <= @included_miles,
       do: {:ok, base_price}

  defp calculate_price!(distance, base_price, additional_price)
       when distance > @included_miles,
       do: {:ok, base_price + additional_price * (distance - @included_miles)}
end
