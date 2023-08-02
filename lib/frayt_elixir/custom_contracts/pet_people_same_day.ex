defmodule FraytElixir.CustomContracts.PetPeopleSameDay do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      standard: %Tier{
        parameters: [weight: 200],
        service_level: 1,
        driver_cut: 0.80,
        zones: %{
          10.0 => %{price: 19_00, driver_cut: 0.80},
          20.0 => %{price: 25_00, driver_cut: 0.80}
        }
      }
    ],
    stack_tiers?: false,
    parameters: [:weight]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
