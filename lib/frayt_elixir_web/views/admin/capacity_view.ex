defmodule FraytElixirWeb.Admin.CapacityView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions
  import FraytElixir.DistanceConversion
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Shipment.{MatchState, Match}
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  alias FraytElixir.DriverDocuments
  import FraytElixirWeb.Admin.DriversView, only: [render_documents_approval_states: 1]

  @assignable_states MatchState.assignable_range()
  def is_assignable(%Match{state: state}), do: state in @assignable_states

  def is_assigned_driver?(%Match{} = match, %Driver{} = driver) do
    match.driver_id == driver.id
  end

  def get_driver_location(%Driver{current_location: location}, :current_location),
    do: location

  def get_driver_location(%Driver{address: address}, :address),
    do: address

  def get_driver_location(_, _), do: nil

  def driver_address(
        _driver,
        :current_location
      ),
      do: nil

  def driver_address(%Driver{address: driver_address}, :address),
    do: display_address(driver_address)

  def driver_address(_, _), do: "-"

  def display_capacity_error(error) do
    case error do
      :address_not_found -> "Pickup address was not found"
      :no_address -> "No Pickup address selected"
      %Ecto.Changeset{} = changeset -> humanize_errors(changeset)
      e when is_binary(e) -> e
    end
  end

  def is_missing_required_need?(match, vehicles) do
    %{match_stops: stops, unload_method: unload_method} = match

    req_pallet_jack? = Enum.any?(stops, & &1.needs_pallet_jack)
    req_pallet_or_lift? = req_pallet_jack? or unload_method == :lift_gate
    vehicle_has_lift_or_jack? = Enum.any?(vehicles, &(&1.lift_gate || &1.pallet_jack))

    req_pallet_or_lift? and not vehicle_has_lift_or_jack?
  end
end
