defmodule FraytElixir.Shipment.MatchStopItem do
  use FraytElixir.Schema

  alias FraytElixir.Shipment.{
    MatchStop,
    MatchStopItemType,
    BarcodeReading
  }

  schema "match_stop_items" do
    field :height, :float
    field :length, :float
    field :pieces, :integer
    field :volume, :integer
    field :weight, :float
    field :width, :float
    field :type, MatchStopItemType.Type, default: :item
    field :external_id, :string
    field :description, :string
    field :barcode, :string
    field :barcode_pickup_required, :boolean, default: false
    field :barcode_delivery_required, :boolean, default: false
    field :declared_value, :integer

    has_many :barcode_readings, BarcodeReading

    belongs_to :match_stop, MatchStop, foreign_key: :match_stop_id, on_replace: :delete

    timestamps()
  end

  @allowed_fields ~w(
    type weight height length width pieces description volume external_id
    barcode barcode_pickup_required barcode_delivery_required declared_value
  )a

  @doc false
  def changeset(match_stop_item, attrs) do
    match_stop_item
    |> cast(attrs, @allowed_fields)
    |> validate_required([:weight, :pieces, :type])
    |> validate_number(:pieces, greater_than_or_equal_to: 1)
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> validate_number(:length, greater_than_or_equal_to: 0)
    |> validate_number(:height, greater_than_or_equal_to: 0)
    |> validate_number(:width, greater_than_or_equal_to: 0)
    |> validate_number(:declared_value, greater_than_or_equal_to: 0)
    |> validate_number(:volume, greater_than_or_equal_to: 0)
    |> validate_required_when(:width, [{:volume, :equal_to, nil}])
    |> validate_required_when(:height, [{:volume, :equal_to, nil}])
    |> validate_required_when(:length, [{:volume, :equal_to, nil}])
    |> validate_required_when(:volume, [
      {:width, :equal_to, nil},
      {:length, :equal_to, nil},
      {:height, :equal_to, nil}
    ])
  end

  def validation_changeset(item, attrs, _match, _stop), do: changeset(item, attrs)

  # TODO: Enforce validation for max weight. This is currently not possible due to Walmart not always providing the item weight.
  # def validation_changeset(item, attrs, match, _stop) do
  #   max_weight = get_max_item_weight(match)

  #   item
  #   |> changeset(attrs)
  #   |> validate_number(:weight, less_than_or_equal_to: max_weight)
  # end

  # defp get_max_item_weight(match) do
  #   case match.vehicle_class do
  #     4 -> 250
  #     _ -> 75
  #   end
  # end
end
