defmodule FraytElixir.CustomContracts.TBCSameDay do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      micro: %Tier{
        parameters: [weight: 50, pieces: 1],
        per_mile: 1_20,
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          15.0 => %{price: 18_00, driver_cut: 0.80},
          25.0 => %{price: 21_00, driver_cut: 0.80},
          35.0 => %{price: 25_00, driver_cut: 0.80}
        }
      },
      lite: %Tier{
        parameters: [weight: 200, pieces: 4],
        per_mile: 1_35,
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          15.0 => %{price: 22_00, driver_cut: 0.80},
          25.0 => %{price: 26_00, driver_cut: 0.80},
          35.0 => %{price: 35_00, driver_cut: 0.80}
        }
      },
      standard: %Tier{
        parameters: [weight: 500, pieces: 8],
        per_mile: 1_50,
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          15.0 => %{price: 30_00, driver_cut: 0.80},
          25.0 => %{price: 35_00, driver_cut: 0.80},
          35.0 => %{price: 43_00, driver_cut: 0.80}
        }
      },
      large: %Tier{
        parameters: [weight: 2_500, pieces: 25],
        per_mile: 1_75,
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          10.0 => %{price: 75_00, driver_cut: 0.80},
          20.0 => %{price: 95_00, driver_cut: 0.80},
          30.0 => %{price: 11_000, driver_cut: 0.80}
        }
      }
    ],
    stacked_driver_cut: 0.80,
    parameters: [:weight, :pieces]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
