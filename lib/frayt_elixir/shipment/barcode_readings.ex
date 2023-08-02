defmodule FraytElixir.Shipment.BarcodeReadings do
  @moduledoc """
  The BarcodeReading context.
  """

  import Ecto.Query, warn: false

  alias FraytElixir.Shipment.{
    Match,
    MatchStop,
    MatchStopItem,
    BarcodeReading
  }

  alias FraytElixir.Repo
  alias FraytElixirWeb.UploadHelper

  @doc """
  Creates a BarcodeReading.

  ## Examples

      iex> create(%{field: value})
      {:ok, %BarcodeReading{}}

      iex> create(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
      iex> create(%{photo: bad_photo})
      {:error, :invalid_file}

  """
  def create(item, %{photo: photo} = attrs) when is_binary(photo) do
    case UploadHelper.file_from_base64(photo, "photo.jpg", :missing_photo) do
      {:ok, photo} -> create(item, attrs |> Map.put(:photo, photo))
      {:error, _} -> {:error, :invalid_file}
    end
  end

  def create(item, attrs) do
    %BarcodeReading{}
    |> BarcodeReading.changeset(item, attrs)
    |> Repo.insert()
  end

  # Return a query with the match stop items
  # for a given match_stop_id.
  defp match_stop_items_qry(match_stop_id) do
    from msi in MatchStopItem,
      where: msi.match_stop_id == ^match_stop_id,
      preload: [:barcode_readings]
  end

  @doc """
  Returns all match stop items for a given match_stop_id
  that require barcode scanning at pickup or delivery time
  and its barcode readings preloaded.
  """
  def list_match_stop_items_required(match_stop_id, :pickup) do
    qry =
      from msi in match_stop_items_qry(match_stop_id),
        where: msi.barcode_pickup_required == true

    Repo.all(qry)
  end

  def list_match_stop_items_required(match_stop_id, :delivery) do
    qry =
      from msi in match_stop_items_qry(match_stop_id),
        where: msi.barcode_delivery_required == true

    Repo.all(qry)
  end

  @doc """
  Check if all items that require barcode scanning have already been scanned.

  Returns a tuple {:ok, nil} when true or {:error, msg} when false.
  """
  def barcode_reading_present_when_required?(%MatchStop{id: match_stop_id}, reading_type) do
    match_stop_items = list_match_stop_items_required(match_stop_id, reading_type)

    barcode_readings =
      Enum.flat_map(match_stop_items, & &1.barcode_readings)
      |> Enum.filter(&(&1.type == reading_type))

    if length(match_stop_items) === length(barcode_readings) do
      {:ok, nil}
    else
      {:error, "The barcode of some item has not been scanned."}
    end
  end

  def barcode_reading_present_when_required?(%Match{} = match, reading_type) do
    match.match_stops
    |> Enum.map(&barcode_reading_present_when_required?(&1, reading_type))
    |> Enum.filter(fn {status, _} -> status == :error end)
    |> case do
      [{:error, message} | _] -> {:error, message}
      [] -> {:ok, nil}
    end
  end
end
