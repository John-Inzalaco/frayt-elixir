defmodule FraytElixirWeb.API.V2x1.Schemas.BarcodeReading do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Barcode Reading",
    description: "",
    type: :object,
    properties: %{
      type: %Schema{
        type: :string,
        enum: [:pickup, :delivery],
        description: "Reading type it could be pickup or delivery"
      },
      state: %Schema{
        type: :string,
        enum: [:captured, :missing],
        description: "State of reading ir could be captured or missing"
      },
      photo: %Schema{
        type: :string,
        description: "Item photo. A photo should be taken when a barcode can't be read"
      },
      barcode: %Schema{type: :string, description: "Barcode for Match Stop Item"},
      inserted_at: %Schema{
        type: :string,
        description: "The date & time this reading was created",
        format: :"date-time"
      }
    },
    example: %{
      "type" => "pickup",
      "state" => "captured",
      "photo" => "base64:image",
      "barcode" => "123barcode456",
      "inserted_at" => "2030-01-01T00:19:50Z"
    }
  })
end
