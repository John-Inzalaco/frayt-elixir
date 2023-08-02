defmodule FraytElixir.Shipment.Batch do
  alias FraytElixir.Import
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixir.Repo
  alias Ecto.Multi
  alias FraytElixir.Matches

  def create(
        %Plug.Upload{
          path: path
        },
        shipper
      ) do
    shipper =
      shipper
      |> Repo.preload([:credit_card, location: [:company]])

    batch_inserts =
      File.stream!(path)
      |> CSV.decode()
      |> Enum.to_list()
      |> Import.convert_to_map_list()
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {order, index}, multi ->
        scheduled = !!(Map.get(order, "scheduled_pickup") || Map.get(order, "scheduled_dropoff"))

        attrs =
          order
          |> FraytElixir.AtomizeKeys.atomize_keys()
          |> fix_csv_values()
          |> Matches.convert_attrs_to_multi_stop()
          |> Map.put(:state, :inactive)
          |> Map.put(:scheduled, scheduled)

        multi
        |> Matches.create_batch_match_changes(attrs, shipper, index)
      end)

    Repo.transaction(batch_inserts)
  end

  def fix_csv_values(
        %{
          vehicle_class: vehicle,
          dimensions_height: height,
          dimensions_length: length,
          dimensions_width: width,
          weight: weight,
          job_number: job_number,
          dropoff_notes: dropoff_notes,
          scheduled_pickup: scheduled_pickup,
          scheduled_dropoff: scheduled_dropoff,
          load_fee: load_fee,
          pallet_jack: needs_pallet_jack
        } = map
      ) do
    map
    |> Map.merge(%{
      service_level: 1,
      height: Import.convert_to_integer(height),
      length: Import.convert_to_integer(length),
      width: Import.convert_to_integer(width),
      weight: Import.convert_to_integer(weight),
      po: job_number,
      delivery_notes: dropoff_notes,
      pickup_at: DisplayFunctions.handle_empty_string(scheduled_pickup),
      dropoff_at: DisplayFunctions.handle_empty_string(scheduled_dropoff),
      vehicle_class: Import.convert_to_integer(vehicle),
      has_load_fee: load_fee,
      needs_pallet_jack: needs_pallet_jack
    })
  end
end
