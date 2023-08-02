defmodule FraytElixir.Shipment.MatchState do
  @deprecated_states %{
    inactive: -3,
    driver_canceled: -2,
    admin_canceled: -1,
    canceled: 0,
    pending: 1,
    scheduled: 2,
    assigning_driver: 3,
    accepted: 4,
    en_route_to_pickup: 5,
    arrived_at_pickup: 6,
    picked_up: 7,
    en_route_to_dropoff: 8,
    arrived_at_dropoff: 9,
    signed: 10,
    delivered: 11,
    charged: 12
  }

  @states %{
    unable_to_pickup: %{
      index: -3,
      description: "the driver was unable to pick up all items."
    },
    driver_canceled: %{
      index: -2,
      description:
        "the driver has removed himself from a Match. The Match itself is not canceled and will be sent out to other available drivers."
    },
    admin_canceled: %{
      index: -1,
      description: "has been canceled by the Frayt team"
    },
    canceled: %{
      index: -1,
      description: "was canceled by the shipper"
    },
    pending: %{
      index: 0,
      description: "has been estimated, but not authorized"
    },
    inactive: %{
      index: 1,
      description: "is awaiting action from the Frayt team before it can be sent out to drivers"
    },
    scheduled: %{
      index: 2,
      description: "is currently scheduled for a future time, and has not been sent to drivers"
    },
    assigning_driver: %{
      index: 3,
      description: "we are in the process of finding an available driver to assign to this Match"
    },
    accepted: %{
      index: 4,
      description: "has been accepted by a driver, but is not yet on the way"
    },
    en_route_to_pickup: %{
      index: 5,
      description: "the driver is on the way to the pickup location"
    },
    arrived_at_pickup: %{
      index: 6,
      description: "the driver has arrived at the pickup location"
    },
    picked_up: %{
      index: 7,
      description:
        "the driver has picked up all items. Details updates on individual stops can be found under the stops state."
    },
    en_route_to_return: %{
      index: 8,
      description: "the driver is returning back to the pick up point."
    },
    arrived_at_return: %{
      index: 9,
      description: "the driver has reached the pickup point."
    },
    completed: %{
      index: 10,
      description: "all stops have been completed, but not yet charged"
    },
    charged: %{
      index: 11,
      description: "the Match has been completed and charged"
    }
  }

  use FraytElixir.Type.StateEnum,
    states: @states,
    types: ["en_route_to_dropoff", "arrived_at_dropoff", "signed", "delivered"],
    names: [
      {:canceled, "Shipper Canceled"},
      {:admin_canceled, "Admin Canceled"}
    ]

  def deprecated_states, do: @deprecated_states

  def is_live?(state),
    do:
      live_range()
      |> Enum.member?(state)

  def all_range, do: visible_range() ++ canceled_range() ++ inactive_range()

  def live_range, do: range(:accepted, :arrived_at_return) ++ [:unable_to_pickup]

  def cancelable_range, do: range(:inactive, :arrived_at_pickup)

  def restricted_cancelable_range, do: range(:inactive, :assigning_driver)

  def active_range,
    do: range(:assigning_driver, :arrived_at_return) ++ [:unable_to_pickup, :driver_canceled]

  def completed_range, do: range(:completed, :charged)

  def charged_range, do: canceled_range() ++ [:charged]

  def assigned_range, do: live_range() ++ charged_range()

  def editable_range, do: range(:inactive, :charged) ++ [:unable_to_pickup]

  def visible_range, do: range(:scheduled, :charged) ++ [:unable_to_pickup]

  def canceled_range, do: range(:admin_canceled, :canceled)

  def scheduled_range, do: [:scheduled]

  def inactive_range, do: [:inactive]

  def assignable_range, do: [:inactive, :scheduled, :assigning_driver]

  def en_route_range, do: [:en_route_to_pickup, :en_route_to_return]
end
