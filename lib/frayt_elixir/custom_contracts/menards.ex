defmodule FraytElixir.CustomContracts.Menards do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [weight: 100],
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          15.0 => %{price: 20_00, driver_cut: 0.80},
          25.0 => %{price: 30_00, driver_cut: 0.80},
          35.0 => %{price: 40_00, driver_cut: 0.80}
        }
      },
      standard: %Tier{
        parameters: [weight: 200],
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          15.0 => %{price: 22_00, driver_cut: 0.80},
          25.0 => %{price: 32_00, driver_cut: 0.80},
          35.0 => %{price: 45_00, driver_cut: 0.80}
        }
      },
      large: %Tier{
        parameters: [weight: 300],
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          15.0 => %{price: 25_00, driver_cut: 0.80},
          25.0 => %{price: 35_00, driver_cut: 0.80},
          35.0 => %{price: 50_00, driver_cut: 0.80}
        }
      }
    ],
    stacked_driver_cut: 0.80,
    parameters: [:weight]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
