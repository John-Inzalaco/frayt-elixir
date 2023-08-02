defmodule FraytElixir.CustomContracts.WorldElectric do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      micro: %Tier{
        parameters: [weight: 50, pieces: 1],
        per_mile: 1_85,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          15.0 => %{price: 19_00, driver_cut: 0.75},
          25.0 => %{price: 22_00, driver_cut: 0.75},
          35.0 => %{price: 27_00, driver_cut: 0.75}
        }
      },
      lite: %Tier{
        parameters: [weight: 200, pieces: 4],
        per_mile: 1_85,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          15.0 => %{price: 25_00, driver_cut: 0.75},
          25.0 => %{price: 29_00, driver_cut: 0.75},
          35.0 => %{price: 34_00, driver_cut: 0.75}
        }
      },
      standard: %Tier{
        parameters: [weight: 500, pieces: 8],
        per_mile: 1_85,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          15.0 => %{price: 35_00, driver_cut: 0.75},
          25.0 => %{price: 40_00, driver_cut: 0.75},
          35.0 => %{price: 48_00, driver_cut: 0.75}
        }
      },
      large: %Tier{
        parameters: [weight: 2500, pieces: 20],
        per_mile: 1_85,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          15.0 => %{price: 85_00, driver_cut: 0.75},
          25.0 => %{price: 115_00, driver_cut: 0.75},
          35.0 => %{price: 135_00, driver_cut: 0.75}
        }
      }
    ],
    stacked_driver_cut: 0.75,
    parameters: [:weight, :pieces]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
