defmodule FraytElixirWeb.API.V2x1.Schemas.BatchHelper do
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.NewMatchStop

  def shared_props(props),
    do:
      Map.merge(
        %{
          po: %Schema{
            type: :string,
            description: "PO or Job Number for this batch",
            nullable: true
          },
          contract: %Schema{
            type: :string,
            description:
              "If you have customized agreed-upon pricing with Frayt, you will need to setup a corresponding contract identifier provided to you by the Frayt team. Pricing defaults to our standard rates with the identifier in place.",
            nullable: true
          },
          pickup_notes: %Schema{
            type: :string,
            description: "Instructions for Driver when picking up a Match",
            nullable: true
          },
          pickup_at: %Schema{
            type: :string,
            description: "Scheduled Pick up Date/Time (ISO format)",
            format: :"date-time"
          },
          complete_by: %Schema{
            type: :string,
            description:
              "Date/Time (ISO format) that all generated Matches need to be completed by. Any stops that can't be delivered in this time will be left unhandled.",
            format: :"date-time",
            nullable: true
          }
        },
        props
      )

  def shared_example(example),
    do:
      Map.merge(
        %{
          "po" => "ABCDEFG",
          "pickup_notes" => "Go to the back",
          "pickup_at" => "2030-01-01T00:00:00Z",
          "complete_by" => "2030-01-01T10:00:00Z"
        },
        example
      )
end

defmodule FraytElixirWeb.API.V2x1.Schemas.Batch do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixir.Shipment

  alias FraytElixirWeb.API.V2x1.Schemas.{
    BatchHelper,
    Shipper,
    Address,
    Match,
    MatchStop,
    StateTransition
  }

  alias FraytElixir.Shipment.BatchState

  OpenApiSpex.schema(%{
    title: "Batch",
    description: "A collection of Stops and Matches that have been routed and batched together.",
    type: :object,
    properties:
      BatchHelper.shared_props(%{
        id: %Schema{type: :string, description: "Unique identifier for batch"},
        state: %Schema{
          type: :string,
          enum: BatchState.all_states(),
          description: """
          Current state of batch<br/>
          <br/>A successful Batch will transition through all of these states:<br/>
          #{BatchState.render_range(:success)}
          <hr/>
          #{BatchState.render_descriptions()}
          """
        },
        service_level: %Schema{
          type: :integer,
          enum: Shipment.get_attribute(:service_levels) |> Map.keys(),
          description: "Service level for all Matches in this batch"
        },
        shipper: Shipper,
        origin_address: %Schema{
          type: :object,
          oneOf: [Address],
          description: "The pickup point for all Matches in this batch"
        },
        matches: %Schema{
          type: :array,
          items: Match,
          description:
            "List of Matches that were created in this batch. This will be an empty array until the state of the batch is `routing_complete`"
        },
        stops: %Schema{description: "Stops", type: :array, items: MatchStop},
        state_transition: %Schema{type: :object, oneOf: [StateTransition]}
      }),
    example:
      BatchHelper.shared_example(%{
        "id" => "44e216c1-3ebc-4ce0-9a6b-1b94d9c2f25b",
        "state" => "routing",
        "service_level" => 1,
        "shipper" => Shipper.schema().example,
        "origin_address" => Address.schema().example,
        "matches" => [],
        "stops" => [MatchStop.schema().example, MatchStop.schema().example],
        "state_transition" => nil
      })
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.BatchRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{BatchHelper, NewMatchStop}

  OpenApiSpex.schema(%{
    title: "BatchRequest",
    description: "POST body for creating a batch",
    type: :object,
    properties:
      BatchHelper.shared_props(%{
        shipper_email: %Schema{
          type: :string,
          format: :email,
          description: "Email of shipper this Match should belong to if other than the default.",
          nullable: true
        },
        origin_address: %Schema{
          type: :string,
          description: "The pickup point for all Matches in this batch",
          example: "708 Walnut St. Cincinnati, OH 45202"
        },
        stops: %Schema{description: "Stops", type: :array, minItems: 1, items: NewMatchStop}
      }),
    required: [:stops, :origin_address, :pickup_at],
    example:
      BatchHelper.shared_example(%{
        "origin_address" => "708 Walnut St. Cincinnati, OH 45202",
        "stops" => [
          NewMatchStop.schema().example
        ]
      })
  })
end
