defmodule FraytElixirWeb.API.V2x1.Schemas.MatchStopHelper do
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{MatchStopItem, Contact}

  def shared_props(props),
    do:
      Map.merge(
        %{
          identifier: %Schema{
            type: :string,
            description:
              "Unique identifier from external system. This will be returned in all responses, including webhooks.",
            nullable: true
          },
          dropoff_by: %Schema{
            type: :string,
            format: :"date-time",
            description: "The latest the driver should arrive at this Stop",
            nullable: true
          },
          delivery_notes: %Schema{
            type: :string,
            description: "Notes for the driver regarding delivery",
            nullable: true
          },
          has_load_fee: %Schema{
            type: :boolean,
            default: false,
            description: "Set to `true` if the driver will be required to unload the items"
          },
          po: %Schema{
            type: :string,
            default: nil,
            description: "PO or Job Number for this Match Stop"
          },
          needs_pallet_jack: %Schema{
            type: :boolean,
            default: false,
            description:
              "Set to `true` if the driver will be required to unload pallets from a box truck with a pallet jack"
          },
          self_recipient: %Schema{
            type: :boolean,
            default: true,
            description:
              "When set to `true`, `recipient_name`, `recipient_phone`, and `recipient_email` will be ignored"
          },
          signature_required: %Schema{
            type: :boolean,
            default: true,
            description:
              "When set to `true`, Drivers will require requesting the customer's signature at delivery time."
          },
          items: %Schema{
            type: :array,
            minItems: 1,
            items: MatchStopItem,
            description: "Items to be delivered at this Stop"
          },
          recipient: %Schema{
            type: :object,
            oneOf: [Contact],
            description: "Contact for this stop's recipient",
            example: Contact.schema().example
          }
        },
        props
      )

  def shared_example(example),
    do:
      Map.merge(
        %{
          "identifier" => "1234567890",
          "dropoff_by" => "2030-01-01T01:01:00Z",
          "delivery_notes" => "Leave by the door",
          "has_load_fee" => true,
          "needs_pallet_jack" => false,
          "self_recipient" => false,
          "signature_required" => false,
          "po" => "PO or Job Number for this Match Stop",
          "items" => [MatchStopItem.schema().example],
          "recipient" => Contact.schema().example
        },
        example
      )
end

defmodule FraytElixirWeb.API.V2x1.Schemas.NewMatchStop do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x2.Schemas.AddressRequest
  alias FraytElixirWeb.API.V2x1.Schemas.{MatchStopItem, MatchStopHelper}

  OpenApiSpex.schema(%{
    title: "New MatchStop",
    description: "A Stop on a Match",
    type: :object,
    properties:
      MatchStopHelper.shared_props(%{
        tip_price: %Schema{
          type: :integer,
          description: "Additional tip for the driver in US cents (¢)",
          default: 0
        },
        destination_address: %Schema{
          type: :object,
          oneOf: [%Schema{type: :string}, AddressRequest],
          description: "The dropoff point for this Stop"
        }
        # destination_photo_required: %Schema{
        #   type: :boolean,
        #   description: "Whether a POD photo is required"
        # }
      }),
    required: [:items, :destination_address],
    example:
      MatchStopHelper.shared_example(%{
        "tip_price" => 1000,
        "destination_address" => "708 Walnut Street 500, Cincinnati, Ohio 45202"
        # "destination_photo_required" => false
      })
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.UpdateMatchStop do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{UpdateMatchStopItem, MatchStopHelper}

  OpenApiSpex.schema(%{
    title: "Update MatchStop",
    description: "A Stop on a Match",
    type: :object,
    properties:
      MatchStopHelper.shared_props(%{
        tip_price: %Schema{
          type: :integer,
          description: "Additional tip for the driver in US cents (¢)",
          default: 0
        },
        destination_address: %Schema{
          type: :string,
          description: "The dropoff point for this Stop"
        },
        items: %Schema{
          type: :array,
          minItems: 1,
          items: UpdateMatchStopItem,
          description: "Items to be delivered at this Stop"
        }
        # destination_photo_required: %Schema{
        #   type: :boolean,
        #   description: "Whether a POD photo is required"
        # }
      })
      |> Map.delete(:items),
    required: [],
    example:
      MatchStopHelper.shared_example(%{
        "tip_price" => 1000,
        "destination_address" => "708 Walnut St. Cincinnati, OH 45202"
        # "destination_photo_required" => false
      }),
    struct?: false
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.MatchStop do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias FraytElixirWeb.API.V2x1.Schemas.{
    MatchStopHelper,
    MatchStopItem,
    Address,
    Contact,
    StateTransition,
    ETA
  }

  alias FraytElixir.Shipment.MatchStopState

  OpenApiSpex.schema(%{
    title: "MatchStop",
    description: "A Stop on a Match",
    type: :object,
    properties:
      MatchStopHelper.shared_props(%{
        id: %Schema{type: :string, description: "Unique identifier for Match Stop"},
        destination_address: %Schema{
          type: :object,
          oneOf: [Address],
          description: "The dropoff point for this Stop",
          example: Address.schema().example
        },
        eta: %Schema{
          type: :object,
          oneOf: [ETA],
          description: "Estimated Time of Arrival"
        },
        state: %Schema{
          type: :string,
          enum: MatchStopState.all_states(),
          description: """
          Current Stop state.<br/>
          <br/>A successful Match Stop will transition through some or all of these states:<br/>
          #{MatchStopState.render_range(:success)}
          <hr/>
          #{MatchStopState.render_descriptions()}
          """
        },
        index: %Schema{
          type: :integer,
          description:
            "The order that each Stop will be delivered in. Will be `nil` until routing is complete"
        },
        driver_tip: %Schema{
          type: :number,
          format: :double,
          description: "Additional tip for the driver in US dollars ($)"
        },
        signature_type: %Schema{
          type: :string,
          enum: [:electronic, :photo],
          description: "Type of signature required"
        },
        signature_instruction: %Schema{
          type: :string,
          description: "Instructions for the driver to sign"
        },
        signature_name: %Schema{
          type: :string,
          description: "Name entered by the signee when accepting the delivery"
        },
        signature_photo: %Schema{
          type: :string,
          format: :uri,
          description: "URL linking to photo of signees signature"
        },
        destination_photo_required: %Schema{
          type: :boolean,
          description: "Whether a POD photo is required"
        },
        destination_photo: %Schema{
          type: :string,
          format: :uri,
          description: "URL linking to POD photo"
        },
        state_transition: %Schema{type: :object, oneOf: [StateTransition]}
      }),
    required: [:items, :destination_address],
    example:
      MatchStopHelper.shared_example(%{
        "id" => "c22206a8-00f5-4fde-8395-c24441263f1b",
        "eta" => ETA.schema().example,
        "state" => "pending",
        "index" => nil,
        "driver_tip" => 10.00,
        "signature_type" => "electronic",
        "signature_instructions" => nil,
        "signature_name" => nil,
        "signature_photo" => nil,
        "destination_photo_required" => false,
        "destination_photo" => nil,
        "destination_address" => Address.schema().example,
        "recipient" =>
          Contact.schema().example |> Map.put("id", "13e534a0-b239-41d9-aa00-3adb40197388"),
        "items" => [
          MatchStopItem.schema().example |> Map.put("id", "03e534a0-b239-41d9-aa00-3adb40197388")
        ],
        "state_transition" => nil
      })
  })
end
