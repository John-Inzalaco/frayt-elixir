defmodule FraytElixir.EmailView do
  use FraytElixirWeb, :view
  alias FraytElixir.Shipment.{Match}
  import FraytElixir.Shipment, only: [match_fees_for: 2]
  import FraytElixirWeb.DisplayFunctions

  def maybe_show_field(label, value), do: maybe_show_field(label, value, !!value)

  def maybe_show_field(label, value, true),
    do:
      "<p><span class='match-field-label'>#{label}:</span><span class='match-field-value'> #{value}</span></p>"

  def maybe_show_field(_label, _value, _), do: nil

  def match_status_title(%Match{state: :scheduled}), do: "Match Created"
  def match_status_title(%Match{state: :canceled}), do: "You Canceled Your Match"
  def match_status_title(%Match{state: :admin_canceled}), do: "Admin Canceled"
  def match_status_title(%Match{state: :assigning_driver}), do: "Match Confirmation"
  def match_status_title(%Match{state: :accepted}), do: "Driver Assigned"
  def match_status_title(%Match{state: :picked_up}), do: "Cargo Picked Up"
  def match_status_title(%Match{state: :completed}), do: "Match Receipt"
  def match_status_title(%Match{state: :driver_canceled}), do: "Rerouting Drivers"

  def match_status_title(
        %Match{state: :assigning_driver, platform: :deliver_pro},
        %{status_type: :preferred_driver_unassigned}
      ),
      do: "Driver Unassigned"

  def match_status_title(
        %Match{state: :assigning_driver, platform: :deliver_pro},
        %{status_type: :preferred_driver_rejected}
      ),
      do: "Driver Rejected Offer"

  def match_status_title(match, _), do: match_status_title(match)

  def match_status_message(%Match{state: state, shortcode: shortcode, driver: nil})
      when state in [:canceled, :admin_canceled],
      do: "Match ##{shortcode} has been canceled before a driver accepted it."

  def match_status_message(%Match{state: state, shortcode: shortcode})
      when state in [:canceled, :admin_canceled],
      do: "Match ##{shortcode} has been canceled."

  def match_status_message(%Match{
        state: :scheduled,
        shortcode: shortcode
      }),
      do: "Match ##{shortcode} has been created successfully."

  def match_status_message(%Match{
        state: :assigning_driver,
        origin_address: origin_address,
        pickup_at: nil
      }),
      do:
        "The match you requested to be picked up from #{origin_address.formatted_address} is now in process of being assigned to a driver. You will be notified when a driver is on the way."

  def match_status_message(%Match{
        state: :assigning_driver,
        origin_address: origin_address,
        pickup_at: pickup_at
      }),
      do:
        "The match you requested to be picked up from #{origin_address.formatted_address} at #{display_date_time_long(pickup_at, origin_address)} is now in process of being assigned to a driver. You will be notified when a driver is on the way."

  def match_status_message(%Match{state: :accepted, driver: driver}),
    do:
      "We're happy to tell you that our driver #{full_name(driver)} has accepted your Match. You will continue to receive updates on the status of the order."

  def match_status_message(%Match{state: :picked_up, driver: driver}),
    do:
      "We're happy to tell you that our driver #{full_name(driver)} has picked up your cargo. You will continue to receive updates on the status of the order. "

  def match_status_message(%Match{
        state: :completed,
        driver: driver,
        shortcode: shortcode
      }),
      do:
        "Your driver, #{full_name(driver)}, has just confirmed that your Match ##{shortcode} has been delivered."

  def match_status_message(%Match{state: :driver_canceled, shortcode: shortcode}),
    do:
      "We are rerouting drivers to find the closest match. A new driver will be on their way to pick up your Match ##{shortcode} shortly."

  def match_status_message(
        %Match{
          state: :assigning_driver,
          platform: :deliver_pro,
          origin_address: origin_address,
          pickup_at: nil
        },
        %{
          status_type: status_type,
          driver: %{first_name: first_name, last_name: last_name}
        }
      )
      when status_type in [:preferred_driver_rejected, :preferred_driver_unassigned],
      do:
        "#{first_name} #{last_name} did not accept the match you requested to be picked up from #{origin_address.formatted_address}. You may view the match to request a different driver or remove the preferred driver."

  def match_status_message(
        %Match{
          state: :assigning_driver,
          platform: :deliver_pro,
          origin_address: origin_address,
          pickup_at: pickup_at
        },
        %{
          status_type: status_type,
          driver: %{first_name: first_name, last_name: last_name}
        }
      )
      when status_type in [:preferred_driver_rejected, :preferred_driver_unassigned],
      do:
        "#{first_name} #{last_name} did not accept the match you requested to be picked up from #{origin_address.formatted_address} at #{display_date_time_long(pickup_at, origin_address)}. You may view the match to request a different driver or remove the preferred driver."

  def match_status_message(match, _mst), do: match_status_message(match)
end
