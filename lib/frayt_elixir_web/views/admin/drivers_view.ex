defmodule FraytElixirWeb.Admin.DriversView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.DataTable.Helpers, as: Table
  import FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Drivers
  alias FraytElixir.Shipment.Address
  alias FraytElixir.LiveAction
  alias FraytElixir.DriverDocuments
  alias FraytElixir.Document.State, as: DocumentState
  alias FraytElixir.Shipment.VehicleClass
  alias FraytElixir.Markets.Market

  alias FraytElixir.Drivers.{Driver, DriverMetrics, Proficience}

  def driver_city_state(%Driver{address: %Address{city: city, state: state}}),
    do: "#{city}, #{display_state(state)}"

  def driver_city_state(_), do: "-"

  def vehicle_has_photos(vehicle) do
    excluded_images_type = [:insurance, :registration, :carrier_agreement]

    images =
      vehicle
      |> Map.get(:images)
      |> Enum.reject(&(&1 in excluded_images_type))

    length(images) > 0
  end

  def vehicle_has_photo(_vehicle, nil), do: false

  def vehicle_has_photo(%{images: images}, type) do
    Enum.any?(images, &(&1.type == type))
  end

  def display_driver_metric(driver, key, default \\ nil)
  def display_driver_metric(%Driver{metrics: nil}, key, default), do: format_metric(key, default)

  def display_driver_metric(%Driver{metrics: metrics}, key, default) do
    value = Map.get(metrics, key, default)
    format_metric(key, value)
  end

  def format_metric(:total_earned, value), do: display_price(value)
  def format_metric(_key, value), do: value

  def find_driver_photo(driver, type) do
    Enum.find(driver.images, &(&1.type == type))
  end

  def background_check_state_class(turn_state) do
    case turn_state do
      "approved" -> "label--success"
      "rejected" -> "label--critical"
      "withdrawn" -> "label--critical"
      "pending" -> "label--warning"
      _ -> ""
    end
  end

  def render_documents_approval_states(states) do
    Enum.map_join(states, ", ", fn {key, value} ->
      "#{title_case(key)}: #{value}"
    end)
  end
end
