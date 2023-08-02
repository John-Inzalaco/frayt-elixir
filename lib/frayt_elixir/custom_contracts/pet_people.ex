defmodule FraytElixir.CustomContracts.PetPeople do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      standard: %Tier{
        parameters: [weight: 200],
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 25_00, driver_cut: 0.75},
          20.0 => %{price: 30_00, driver_cut: 0.75}
        }
      }
    ],
    stack_tiers?: false,
    parameters: [:weight]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)

  def get_auto_cancel_on_driver_cancel_time_after_acceptance, do: {:ok, 10 * 60 * 1000}

  def get_auto_cancel_on_driver_cancel, do: {:ok, true}

  def get_auto_cancel_time, do: {:ok, 10 * 60 * 1000}
end
