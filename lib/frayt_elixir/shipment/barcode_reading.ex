defmodule FraytElixir.Shipment.BarcodeReading do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset

  alias FraytElixir.{
    Shipment.MatchStopItem,
    Photo
  }

  schema "barcode_readings" do
    field :type, BarcodeTypeEnum
    field :state, BarcodeStateEnum
    field :photo, Photo.Type
    field :barcode, :string
    belongs_to :match_stop_item, MatchStopItem

    timestamps()
  end

  @allowed ~w(type state barcode match_stop_item_id)a

  @doc false
  def changeset(barcode, item, attrs) do
    attrs = attrs |> Map.put(:match_stop_item_id, item.id)

    barcode
    |> cast(attrs, @allowed)
    |> validate_required([:type, :state, :match_stop_item_id])
    |> unique_constraint([:type, :match_stop_item_id],
      message: "has already been scanned for this item"
    )
    |> cast_attachments(attrs, [:photo])
    |> validate_required_when(:photo, [{:state, :equal_to, :missing}])
    |> validate_required_when(:barcode, [{:state, :equal_to, :captured}])
    |> validate_barcode_belongs_to_item(item)
  end

  defp validate_barcode_belongs_to_item(cs, item) do
    state = get_field(cs, :state)
    read_barcode = get_field(cs, :barcode)

    if is_valid_barcode?(read_barcode, item.barcode) || state == :missing do
      cs
    else
      add_error(cs, :barcode, "does not match this item's barcode")
    end
  end

  defp is_valid_barcode?(_, nil), do: true

  defp is_valid_barcode?(read_barcode, item_barcode), do: read_barcode === item_barcode
end
