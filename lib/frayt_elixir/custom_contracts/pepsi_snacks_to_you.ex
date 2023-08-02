defmodule FraytElixir.CustomContracts.PepsiSnacksToYou do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [weight: 60, pieces: 11],
        service_level: 2,
        driver_cut: 0.80,
        per_mile: 85,
        zones: %{
          5.0 => %{price: 17_00, driver_cut: 0.80},
          10.0 => %{price: 18_50, driver_cut: 0.80},
          15.0 => %{price: 20_00, driver_cut: 0.80},
          20.0 => %{price: 20_00, driver_cut: 0.80},
          25.0 => %{price: 24_00, driver_cut: 0.80},
          30.0 => %{price: 27_00, driver_cut: 0.80}
        }
      },
      standard: %Tier{
        parameters: [weight: 150, pieces: 29],
        service_level: 2,
        driver_cut: 0.80,
        per_mile: 100,
        zones: %{
          5.0 => %{price: 20_00, driver_cut: 0.80},
          10.0 => %{price: 23_00, driver_cut: 0.80},
          15.0 => %{price: 32_00, driver_cut: 0.80},
          20.0 => %{price: 36_00, driver_cut: 0.80},
          25.0 => %{price: 40_00, driver_cut: 0.80},
          30.0 => %{price: 42_00, driver_cut: 0.80}
        }
      },
      large: %Tier{
        parameters: [weight: 500, pieces: 99],
        service_level: 2,
        driver_cut: 0.80,
        per_mile: 125,
        zones: %{
          5.0 => %{price: 25_00, driver_cut: 0.80},
          10.0 => %{price: 30_00, driver_cut: 0.80},
          15.0 => %{price: 45_00, driver_cut: 0.80},
          20.0 => %{price: 50_00, driver_cut: 0.80},
          25.0 => %{price: 54_00, driver_cut: 0.80},
          30.0 => %{price: 57_00, driver_cut: 0.80}
        }
      },
      huge: %Tier{
        parameters: [weight: 1000],
        service_level: 2,
        driver_cut: 0.80,
        per_mile: 125,
        zones: %{
          5.0 => %{price: 60_00, driver_cut: 0.80},
          10.0 => %{price: 63_00, driver_cut: 0.80},
          15.0 => %{price: 70_00, driver_cut: 0.80},
          20.0 => %{price: 75_00, driver_cut: 0.80},
          25.0 => %{price: 80_00, driver_cut: 0.80},
          30.0 => %{price: 90_00, driver_cut: 0.80}
        }
      }
    ],
    stack_tiers?: false,
    parameters: [:weight, :pieces]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
