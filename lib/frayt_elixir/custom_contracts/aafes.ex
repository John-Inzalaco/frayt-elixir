defmodule FraytElixir.CustomContracts.AAFES do
  alias FraytElixir.CustomContracts.{Contract, StackedTemplate}
  alias StackedTemplate.Tier

  use Contract

  @config %StackedTemplate{
    tiers: [
      class_0: %Tier{
        parameters: [weight: 99],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 1340, driver_cut: 0.75},
          20.0 => %{price: 1720, driver_cut: 0.75},
          30.0 => %{price: 2100, driver_cut: 0.75}
        }
      },
      class_1: %Tier{
        parameters: [weight: 199],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 1838, driver_cut: 0.75},
          20.0 => %{price: 2600, driver_cut: 0.75},
          30.0 => %{price: 3192, driver_cut: 0.75}
        }
      },
      class_2: %Tier{
        parameters: [weight: 399],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 7200, driver_cut: 0.75},
          20.0 => %{price: 10080, driver_cut: 0.75},
          30.0 => %{price: 12888, driver_cut: 0.75}
        }
      },
      class_3: %Tier{
        parameters: [weight: 599],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 9720, driver_cut: 0.75},
          20.0 => %{price: 15120, driver_cut: 0.75},
          30.0 => %{price: 17424, driver_cut: 0.75}
        }
      },
      class_4: %Tier{
        parameters: [weight: 799],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 16920, driver_cut: 0.75},
          20.0 => %{price: 25200, driver_cut: 0.75},
          30.0 => %{price: 30312, driver_cut: 0.75}
        }
      },
      class_5: %Tier{
        parameters: [weight: 999],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 24120, driver_cut: 0.75},
          20.0 => %{price: 35280, driver_cut: 0.75},
          30.0 => %{price: 43200, driver_cut: 0.75}
        }
      },
      class_6: %Tier{
        parameters: [weight: 1200],
        per_mile: 2_00,
        service_level: 2,
        driver_cut: 0.75,
        zones: %{
          10.0 => %{price: 31320, driver_cut: 0.75},
          20.0 => %{price: 45360, driver_cut: 0.75},
          30.0 => %{price: 56088, driver_cut: 0.75}
        }
      }
    ],
    stack_tiers?: false,
    stacked_driver_cut: 0.75,
    parameters: [:weight]
  }

  @impl true
  def calculate_pricing(match), do: StackedTemplate.calculate_pricing(match, @config)
end
