defmodule FraytElixirWeb.API.V2x1.Schemas do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.MatchStop

  def shared_props(schema, props),
    do: Map.merge(shared_props(schema), props)

  def shared_props(:batch),
    do: %{
      identifier: %Schema{
        type: :string,
        description:
          "Unique identifier from external system. This will be returned in all responses, including webhooks."
      },
      po: %Schema{
        type: :string,
        description: "PO or Job Number for this batch"
      },
      contract: %Schema{
        type: :string,
        description: "Custom contract key"
      },
      origin_address: %Schema{
        type: :string,
        description: "The pickup point for all Matches in this batch",
        example: "1311 Vine St. Cincinnati, OH 45202"
      },
      pickup_notes: %Schema{
        type: :string,
        description: "Instructions for Driver when picking up a Match"
      },
      pickup_at: %Schema{
        type: :string,
        description: "Scheduled Pick up Date/Time (ISO format)",
        format: :"date-time",
        example: "2020-09-28T09:31"
      },
      stops: %Schema{description: "Stops", type: :array, minItems: 1, items: MatchStop}
    }

  def error_code_properties do
    %{
      code: %Schema{type: :string, description: "Error code"},
      message: %Schema{
        type: :string,
        description: "Human readable message explaining the error"
      }
    }
  end
end
