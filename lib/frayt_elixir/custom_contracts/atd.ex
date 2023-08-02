defmodule FraytElixir.CustomContracts.Atd do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      lite: %Tier{
        parameters: [weight: 200, pieces: 4],
        per_mile: 150,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          15.0 => %{price: 2500, driver_cut: 0.75},
          25.0 => %{price: 3000, driver_cut: 0.75},
          35.0 => %{price: 3800, driver_cut: 0.75}
        }
      },
      standard: %Tier{
        parameters: [weight: 500, pieces: 8],
        per_mile: 175,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          15.0 => %{price: 3500, driver_cut: 0.75},
          25.0 => %{price: 4000, driver_cut: 0.75},
          35.0 => %{price: 4800, driver_cut: 0.75}
        }
      }
    ],
    state_markup: %{
      "CA" => 0.4,
      "OR" => 0.4,
      "WA" => 0.4,
      "IL" => 0.3,
      "MD" => 0.3,
      "PA" => 0.25,
      "SC" => 0.25,
      "OH" => 0.25,
      "NY" => 0.5,
      "NJ" => 0.3
    },
    stacked_driver_cut: 0.85,
    parameters: [:weight, :pieces]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
