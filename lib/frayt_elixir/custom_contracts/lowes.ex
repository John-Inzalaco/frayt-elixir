defmodule FraytElixir.CustomContracts.Lowes do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      micro: %Tier{
        parameters: [
          dimensions: {48, 32, 17},
          weight: 50
        ],
        per_mile: 1_20,
        service_level: 1,
        driver_cut: 0.82,
        zones: %{
          5.0 => %{price: 1800, driver_cut: 0.82},
          10.0 => %{price: 2000, driver_cut: 0.82},
          15.0 => %{price: 2300, driver_cut: 0.82},
          20.0 => %{price: 2500, driver_cut: 0.82}
        }
      },
      lite: %Tier{
        parameters: [
          dimensions: {48, 32, 17},
          weight: 250
        ],
        per_mile: 1_20,
        service_level: 1,
        driver_cut: 0.82,
        zones: %{
          5.0 => %{price: 2000, driver_cut: 0.82},
          10.0 => %{price: 2300, driver_cut: 0.82},
          15.0 => %{price: 2600, driver_cut: 0.82},
          20.0 => %{price: 2900, driver_cut: 0.82}
        }
      },
      lite_cargo: %Tier{
        parameters: [
          dimensions: {97, 49, 53},
          weight: 250
        ],
        per_mile: 1_35,
        service_level: 1,
        driver_cut: 0.82,
        zones: %{
          5.0 => %{price: 3000, driver_cut: 0.82},
          10.0 => %{price: 3200, driver_cut: 0.82},
          15.0 => %{price: 3400, driver_cut: 0.82},
          20.0 => %{price: 3600, driver_cut: 0.82}
        }
      },
      standard: %Tier{
        parameters: [
          dimensions: {97, 49, 53},
          weight: 600
        ],
        per_mile: 1_50,
        service_level: 1,
        driver_cut: 0.82,
        zones: %{
          5.0 => %{price: 4500, driver_cut: 0.82},
          10.0 => %{price: 5000, driver_cut: 0.82},
          15.0 => %{price: 5500, driver_cut: 0.82},
          20.0 => %{price: 6000, driver_cut: 0.82}
        }
      },
      large: %Tier{
        parameters: [
          dimensions: {192, 96, 84},
          weight: 1200
        ],
        per_mile: 3_00,
        service_level: 1,
        driver_cut: 0.82,
        zones: %{
          5.0 => %{price: 200_00, driver_cut: 0.82},
          10.0 => %{price: 225_00, driver_cut: 0.82},
          15.0 => %{price: 250_00, driver_cut: 0.82},
          20.0 => %{price: 275_00, driver_cut: 0.82}
        }
      },
      xlarge: %Tier{
        parameters: [
          dimensions: {192, 96, 84},
          weight: 2500
        ],
        per_mile: 3_00,
        service_level: 1,
        driver_cut: 0.82,
        zones: %{
          5.0 => %{price: 250_00, driver_cut: 0.82},
          10.0 => %{price: 275_00, driver_cut: 0.82},
          15.0 => %{price: 300_00, driver_cut: 0.82},
          20.0 => %{price: 325_00, driver_cut: 0.82}
        }
      }
    ],
    fees: [
      item_handling_fee: [lumber: 0_50, sheet_rock: 0_75],
      load_fee: %{
        251 => {24_99, 18_74}
      },
      lift_gate_fee: {30_00, 22_50}
    ],
    stack_tiers?: false,
    stacked_driver_cut: 0.82,
    parameters: [:weight, :dimensions]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
