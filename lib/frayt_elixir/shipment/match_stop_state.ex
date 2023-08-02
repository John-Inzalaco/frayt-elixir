defmodule FraytElixir.Shipment.MatchStopState do
  use FraytElixir.Type.StateEnum,
    states: %{
      unserved: %{
        index: -5,
        description:
          "this stop was unable to be served in a Match. This state is only possible for Batches. A reason will be provided."
      },
      undeliverable: %{
        index: -4,
        description: "the driver was unable to deliver this stop. A reason will be provided."
      },
      pending: %{
        index: 7,
        description: "the driver is not yet en route. This is the starting state."
      },
      en_route: %{
        index: 8,
        description: "the driver is en route to the stop"
      },
      arrived: %{
        index: 9,
        description: "the driver has arrived at the stop"
      },
      signed: %{
        index: 10,
        description: "the recipient has signed for the delivery of the items"
      },
      delivered: %{
        index: 11,
        description: "the driver has completed the delivery of all items"
      },
      returned: %{
        index: 12,
        description: "the driver has returned the package."
      }
    }

  def all_range, do: range(:undeliverable, :delivered)
  def completed_range, do: [:delivered, :undeliverable]

  def active_range, do: range(:arrived, :signed)

  def live_range, do: range(:en_route, :signed)

  def is_live?(state), do: live_range() |> Enum.member?(state)
end
