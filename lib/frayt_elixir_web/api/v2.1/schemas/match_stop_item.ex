defmodule FraytElixirWeb.API.V2x1.Schemas.MatchStopItem do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixir.Shipment.MatchStopItemType
  alias FraytElixirWeb.API.V2x1.Schemas.BarcodeReading

  OpenApiSpex.schema(%{
    title: "MatchStopItem",
    description: "An Item to be delivered to a stop",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Unique identifier for Match Stop Item"},
      volume: %Schema{
        type: :integer,
        description:
          "Individual volume of each piece in cubic inches (in³). If left empty, it will be calculated automatically based off of other dimensions"
      },
      length: %Schema{type: :integer, description: "Individual length of each piece in inches"},
      width: %Schema{type: :integer, description: "Individual width of each piece in inches"},
      height: %Schema{type: :integer, description: "Individual height of each piece in inches"},
      weight: %Schema{type: :integer, description: "Individual weight of each piece in pounds"},
      pieces: %Schema{type: :integer, description: "Number of items that match these dimensions"},
      declared_value: %Schema{
        type: :integer,
        description: "Declared value of the item being shipped in US cents (¢)"
      },
      barcode: %Schema{type: :string, description: "Value of barcode to be scanned for this item"},
      barcode_pickup_required: %Schema{
        type: :boolean,
        description: "Barcode reading is required for this item on pickup"
      },
      barcode_delivery_required: %Schema{
        type: :boolean,
        description: "Barcode reading is required for this item on delivery"
      },
      description: %Schema{type: :string},
      type: %Schema{
        type: :string,
        enum: MatchStopItemType.all_types(),
        description:
          "Type of item. When at least one item is a pallet, `needs_pallet_jack` will be an avaialable add-on.",
        default: "item"
      },
      barcode_readings: %Schema{description: "", type: :array, items: BarcodeReading}
    },
    required: [:weight, :pieces, :description],
    example: %{
      "width" => 6,
      "length" => 30,
      "height" => 30,
      "weight" => 25,
      "pieces" => 4,
      "volume" => 5400,
      "description" => "A Tire",
      "type" => "item",
      "barcode" => "123barcode456",
      "barcode_pickup_required" => false,
      "barcode_delivery_required" => true,
      "declared_value" => 1500,
      "barcode_readings" => []
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.UpdateMatchStopItem do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixir.Shipment.MatchStopItemType
  alias FraytElixirWeb.API.V2x1.Schemas.BarcodeReading

  OpenApiSpex.schema(%{
    title: "MatchStopItem",
    description: "An Item to be delivered to a stop",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Unique identifier for Match Stop Item"},
      volume: %Schema{
        type: :integer,
        description:
          "Individual volume of each piece in cubic inches (in³). If left empty, it will be calculated automatically based off of other dimensions"
      },
      length: %Schema{type: :integer, description: "Individual length of each piece in inches"},
      width: %Schema{type: :integer, description: "Individual width of each piece in inches"},
      height: %Schema{type: :integer, description: "Individual height of each piece in inches"},
      weight: %Schema{type: :integer, description: "Individual weight of each piece in pounds"},
      pieces: %Schema{type: :integer, description: "Number of items that match these dimensions"},
      declared_value: %Schema{
        type: :integer,
        description: "Declared value of the item being shipped in US cents (¢)"
      },
      barcode: %Schema{type: :string, description: "Value of barcode to be scanned for this item"},
      barcode_pickup_required: %Schema{
        type: :boolean,
        description: "Barcode reading is required for this item on pickup"
      },
      barcode_delivery_required: %Schema{
        type: :boolean,
        description: "Barcode reading is required for this item on delivery"
      },
      description: %Schema{type: :string},
      type: %Schema{
        type: :string,
        enum: MatchStopItemType.all_types(),
        description:
          "Type of item. When at least one item is a pallet, `needs_pallet_jack` will be an avaialable add-on.",
        default: "item"
      },
      barcode_readings: %Schema{description: "", type: :array, items: BarcodeReading}
    },
    required: [],
    example: %{
      "width" => 6,
      "length" => 30,
      "height" => 30,
      "weight" => 25,
      "pieces" => 4,
      "volume" => 5400,
      "description" => "A Tire",
      "type" => "item",
      "barcode" => "123barcode456",
      "declared_value" => 1500,
      "barcode_pickup_required" => false,
      "barcode_delivery_required" => true,
      "barcode_readings" => []
    },
    struct?: false
  })
end
