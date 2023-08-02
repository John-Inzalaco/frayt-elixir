defmodule FraytElixir.CustomContracts.Clmbr do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      standard: %Tier{
        parameters: [weight: 200],
        per_mile: 150,
        service_level: 1,
        driver_cut: 0.75,
        zones: %{
          25.0 => %{price: 150_00, driver_cut: 0.75},
          50.0 => %{price: 200_00, driver_cut: 0.75},
          100.0 => %{price: 240_00, driver_cut: 0.75},
          150.0 => %{price: 300_00, driver_cut: 0.75}
        }
      }
    ],
    stack_tiers?: false,
    parameters: [:weight]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)

  def get_auto_cancel_on_driver_cancel_time_after_acceptance, do: {:ok, 60 * 60 * 1000}

  def get_auto_cancel_on_driver_cancel, do: {:ok, true}

  def get_auto_cancel_time, do: {:ok, 2 * 60 * 60 * 1000}
end
