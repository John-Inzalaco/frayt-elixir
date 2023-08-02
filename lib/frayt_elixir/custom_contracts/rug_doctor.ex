defmodule FraytElixir.CustomContracts.RugDoctor do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      micro: %Tier{
        parameters: [weight: 50, pieces: 1],
        per_mile: 1_32,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 22_00, driver_cut: 0.75},
          15.0 => %{price: 28_00, driver_cut: 0.75},
          20.0 => %{price: 32_00, driver_cut: 0.75},
          25.0 => %{price: 36_00, driver_cut: 0.75}
        }
      },
      lite: %Tier{
        parameters: [weight: 250, pieces: 2],
        per_mile: 1_32,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 25_00, driver_cut: 0.75},
          15.0 => %{price: 30_00, driver_cut: 0.75},
          20.0 => %{price: 35_00, driver_cut: 0.75},
          25.0 => %{price: 40_00, driver_cut: 0.75}
        }
      }
    ],
    stacked_driver_cut: 0.75,
    parameters: [:weight, :pieces]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
