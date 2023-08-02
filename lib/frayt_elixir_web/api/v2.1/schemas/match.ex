defmodule FraytElixirWeb.API.V2x1.Schemas.MatchHelper do
  alias OpenApiSpex.Schema
  alias FraytElixir.Shipment.MatchUnloadMethod
  alias FraytElixirWeb.API.V2x1.Schemas.Contact

  @global_props %{
    service_level: %Schema{
      type: :integer,
      enum: [1, 2],
      description: "Set `1` for dash or `2` for same day"
    },
    vehicle_class: %Schema{
      type: :integer,
      enum: [1, 2, 3, 4],
      description:
        "Set `1` for car, `2` for midsize, `3` for cargo van, and `4` for box truck. <br/> NOTE: This can be left empty only if auto selection is enabled on your account. Reach out to the Frayt team for more details"
    },
    po: %Schema{
      type: :string,
      description: "PO or Job Number for this Match",
      nullable: true
    },
    pickup_notes: %Schema{
      type: :string,
      description: "Instructions for Driver when picking up",
      nullable: true
    },
    pickup_at: %Schema{
      type: :string,
      description: "Scheduled pick up date & time",
      format: :"date-time",
      nullable: true
    },
    dropoff_at: %Schema{
      type: :string,
      description: "Scheduled date & time the final stop is to be delivered by",
      format: :"date-time",
      nullable: true
    },
    identifier: %Schema{
      type: :string,
      description:
        "Unique identifier from external system. This will be returned in all responses, including webhooks.",
      nullable: true
    },
    contract: %Schema{
      type: :string,
      description:
        "If you have customized agreed-upon pricing with Frayt, you will need to setup a corresponding contract identifier provided to you by the Frayt team. Pricing defaults to our standard rates with the identifier in place.",
      nullable: true
    },
    unload_method: %Schema{
      type: :string,
      enum: MatchUnloadMethod.all_types(),
      description:
        "Service type for box trucks. This is required when the vehicle class is box truck",
      nullable: true
    },
    sender: %Schema{
      type: :object,
      oneOf: [Contact],
      description: "The senders contact information, if different than the shippers"
    },
    self_sender: %Schema{
      type: :boolean,
      default: true,
      description: "When set to `true`, `sender` will be ignored"
    }
  }

  @global_example %{
    "service_level" => 1,
    "vehicle_class" => 2,
    "pickup_notes" => "Go to the back",
    "po" => "ABCDEFG",
    "unload_method" => nil,
    "pickup_at" => "2030-02-01T00:00:00Z",
    "dropoff_at" => "2030-02-01T00:30:00Z",
    "identifier" => "1234567890",
    "sender" => Contact.schema().example,
    "self_sender" => false
  }

  def shared_simple_props(props),
    do:
      @global_props
      |> Map.merge(%{
        needs_pallet_jack: %Schema{
          type: :boolean,
          default: false,
          description:
            "Set to `true` if the driver will be required to unload pallets from a box truck with a pallet jack."
        },
        has_load_fee: %Schema{
          type: :boolean,
          default: false,
          description: "Set to `true` if the driver will be required to unload the items"
        },
        delivery_notes: %Schema{
          type: :string,
          description: "Notes for the driver regarding delivery",
          nullable: true
        },
        self_recipient: %Schema{
          type: :boolean,
          default: true,
          description: "Set to `true`, recipient details will be ignored"
        }
      })
      |> Map.merge(props)

  def shared_simple_example(example),
    do:
      @global_example
      |> Map.merge(%{
        "needs_pallet_jack" => false,
        "has_load_fee" => true,
        "self_recipient" => false,
        "delivery_notes" => "Leave by the door"
      })
      |> Map.merge(example)

  def shared_props(props),
    do:
      @global_props
      |> Map.merge(%{
        scheduled: %Schema{
          type: :boolean,
          description: "If this Match is scheduled"
        }
      })
      |> Map.merge(props)

  def shared_example(example),
    do:
      @global_example
      |> Map.merge(%{
        "scheduled" => true
      })
      |> Map.merge(example)

  def update_props(props),
    do:
      shared_props(props)
      |> Map.merge(%{
        vehicle_class: %Schema{
          type: :integer,
          enum: [1, 2, 3, 4],
          description:
            "This field CANNOT be updated and will return an error. If it must be changed, you may cancel the match and create a new one with the desired fields."
        },
        service_level: %Schema{
          type: :integer,
          enum: [1, 2],
          description:
            "This field CANNOT be updated and will return an error. If it must be changed, you may cancel the match and create a new one with the desired fields."
        },
        unload_method: %Schema{
          type: :string,
          enum: MatchUnloadMethod.all_types(),
          description:
            "This field CANNOT be updated and will return an error. If it must be changed, you may cancel the match and create a new one with the desired fields."
        },
        has_load_fee: %Schema{
          type: :boolean,
          default: false,
          description:
            "This field CANNOT be updated and will return an error. If it must be changed, you may cancel the match and create a new one with the desired fields."
        },
        needs_pallet_jack: %Schema{
          type: :boolean,
          default: false,
          description:
            "This field CANNOT be updated and will return an error. If it must be changed, you may cancel the match and create a new one with the desired fields."
        }
      })
      |> Map.delete(:shipper_email)

  def update_example(example),
    do: shared_example(example)
end

defmodule FraytElixirWeb.API.V2x1.Schemas.Match do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias FraytElixirWeb.API.V2x1.Schemas.{
    Driver,
    MatchStop,
    Address,
    MatchHelper,
    MatchFee,
    Contact,
    ETA
  }

  alias FraytElixir.Shipment.MatchState

  OpenApiSpex.schema(%{
    title: "Match",
    description: "A Match",
    type: :object,
    properties:
      MatchHelper.shared_props(%{
        id: %Schema{type: :string, description: "Unique identifier for match"},
        origin_address: %Schema{
          type: :object,
          oneOf: [Address],
          description: "The pickup point for this Match"
        },
        stops: %Schema{
          type: :array,
          items: MatchStop,
          description: "Stops along this Match's route"
        },
        eta: %Schema{
          type: :object,
          oneOf: [ETA],
          description: "Estimated Time of Arrival"
        },
        total_distance: %Schema{
          type: :number,
          format: :float,
          description: "Total distance from origin to all stops"
        },
        total_weight: %Schema{
          type: :integer,
          description: "Sum of weight of all items on all stops in pounds (lbs)"
        },
        total_volume: %Schema{
          type: :integer,
          description: "Sum of volume of all items on all stops in cubic inches (in³)"
        },
        total_price: %Schema{
          type: :number,
          format: :double,
          description: "Total price shipper will be charged in US dollars ($)"
        },
        shortcode: %Schema{
          type: :string,
          description: "Shortcode identifier for this Match"
        },
        state: %Schema{
          type: :string,
          enum: MatchState.all_states(),
          description: """
          Current Match state<br/>
          <br/>A successful Match will transition through some or all of these states:<br/>
          #{MatchState.render_range(:success)}
          <hr/>
          #{MatchState.render_descriptions()}
          """
        },
        inserted_at: %Schema{
          type: :string,
          description: "The date & time this Match was created",
          format: :"date-time"
        },
        picked_up_at: %Schema{
          type: :string,
          description: "The date & time this Match was picked up by the driver",
          format: :"date-time"
        },
        activated_at: %Schema{
          type: :string,
          description: "The date & time this Match was made available to drivers",
          format: :"date-time"
        },
        accepted_at: %Schema{
          type: :string,
          description: "The date & time this Match was accepted by the assigned driver",
          format: :"date-time"
        },
        completed_at: %Schema{
          type: :string,
          description: "The date & time the last stop on this Match was delivered",
          format: :"date-time"
        },
        canceled_at: %Schema{
          type: :string,
          description: "The date & time this Match was canceled",
          format: :"date-time"
        },
        bill_of_lading_required: %Schema{
          type: :boolean,
          description: "Whether this Match requires a bill of lading"
        },
        origin_photo_required: %Schema{
          type: :boolean,
          description: "Whether this Match requires a photo of the origin address"
        },
        bill_of_lading_photo: %Schema{
          type: :string,
          format: :uri,
          description: "URL linking to a photo of the Bill of Lading"
        },
        origin_photo: %Schema{
          type: :string,
          format: :uri,
          description: "URL linking to a photo showing the items picked up"
        },
        driver: %Schema{
          type: :object,
          oneOf: [Driver],
          description: "The driver assigned to this Match"
        },
        cancel_reason: %Schema{
          type: :string,
          description: "Reason for cancellation if a Match has been canceled",
          nullable: true
        },
        rating: %Schema{
          type: :integer,
          description:
            "Rating provided by the Shipper for the driver's performance on this Match",
          nullable: true
        },
        coupon: %Schema{
          type: :object,
          properties: %{
            percentage: %Schema{type: :integer, description: "Discount percent (%) from coupon"},
            code: %Schema{type: :string, description: "Coupon code used"}
          },
          nullable: true
        },
        market: %Schema{
          type: :object,
          properties: %{
            has_box_trucks: %Schema{
              type: :boolean,
              description: "Set to `true` if Box trucks are available in this area"
            }
          },
          nullable: true
        },
        platform: %Schema{
          type: :string,
          enum: [:marketplace, :deliver_pro],
          description: "Whether this is a Marketplace or Deliver Pro match"
        },
        preferred_driver: %Schema{
          type: :string,
          description: "Designated preferred driver for this Match",
          nullable: true
        },
        parking_spot_required: %Schema{
          type: :boolean,
          description: "Whether the parking spot is required"
        }
      }),
    example:
      MatchHelper.shared_example(%{
        "id" => "0000c119-fca6-4531-8b7f-716efb54ef26",
        "stops" => [%{MatchStop.schema().example | "index" => 0}],
        "eta" => ETA.schema().example,
        "fees" => [
          MatchFee.schema().example,
          %{
            MatchFee.schema().example
            | "amount" => 10_00,
              "name" => "Driver Tip",
              "type" => "driver_tip"
          }
        ],
        "driver" => nil,
        "total_distance" => 5.0,
        "total_weight" => 100,
        "total_volume" => 21_600,
        "total_price" => 56.61,
        "price_discount" => 0.00,
        "shortcode" => "ABCDEFGH",
        "state" => "scheduled",
        "inserted_at" => "2030-01-01T00:19:50Z",
        "picked_up_at" => nil,
        "activated_at" => nil,
        "accepted_at" => nil,
        "completed_at" => nil,
        "canceled_at" => nil,
        "bill_of_lading_required" => nil,
        "origin_photo_required" => false,
        "bill_of_lading_photo" => nil,
        "origin_photo" => nil,
        "origin_address" => Address.schema().example,
        "cancel_reason" => nil,
        "rating" => nil,
        "contract" => nil,
        "coupon" => nil,
        "market" => nil,
        "sender" =>
          Contact.schema().example |> Map.put("id", "23e534a0-b239-41d9-aa00-3adb40197388"),
        "optimized_stops" => false,
        "rating_reason" => nil,
        "timezone" => "America/New_York",
        "platform" => "marketplace",
        "preferred_driver" => nil
      })
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.SimpleMatch do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{Address, Driver, MatchHelper}
  alias FraytElixir.Shipment.MatchState

  OpenApiSpex.schema(%{
    title: "SimpleMatch",
    description: "A Simple Match only showing the first stop",
    type: :object,
    properties:
      MatchHelper.shared_simple_props(%{
        id: %Schema{type: :string, description: "Unique identifier for match"},
        origin_address: %Schema{
          type: :object,
          oneOf: [Address],
          description: "The pickup point for this Match"
        },
        destination_address: %Schema{
          type: :object,
          oneOf: [Address],
          description: "The dropoff point for this Match"
        },
        distance: %Schema{
          type: :number,
          format: :float,
          description: "Total distance from origin to destination"
        },
        total_price: %Schema{
          type: :number,
          format: :double,
          description: "Total price shipper will be charged in US dollars ($)"
        },
        tip_price: %Schema{
          type: :number,
          format: :double,
          description: "Driver tip in US dollars ($). This is included in `total_price`"
        },
        load_fee_price: %Schema{
          type: :number,
          format: :double,
          description: "Load fees in US dollars ($). This is included in `total_price`"
        },
        price: %Schema{
          type: :number,
          format: :double,
          description: "Base cost in US dollars ($). This is included in `total_price`"
        },
        scheduled: %Schema{
          type: :boolean,
          description: "If this Match is scheduled"
        },
        shortcode: %Schema{
          type: :string,
          description: "Shortcode identifier for this Match"
        },
        recipient: %Schema{
          type: :object,
          description: "Details of Match's receipient",
          properties: %{
            name: %Schema{type: :string, description: "Name of this Stop's recipient"},
            phone: %Schema{
              type: :string,
              description: "Phone number of this Match's recipient"
            },
            email: %Schema{
              type: :string,
              format: :email,
              description: "Email of this Match's recipient"
            },
            notify: %Schema{
              type: :boolean,
              default: true,
              description:
                "Set to `false` if the recipient should not receive SMS notifications regarding the status of their shipment"
            }
          }
        },
        total_weight: %Schema{
          type: :integer,
          description: "Sum of weight of all items in pounds (lbs)"
        },
        total_volume: %Schema{
          type: :integer,
          description: "Sum of volume of all items in cubic inches (in³)"
        },
        state: %Schema{
          type: :string,
          enum: MatchState.deprecated_states() |> Map.keys(),
          description: "Current Match state"
        },
        inserted_at: %Schema{
          type: :string,
          description: "The date & time this Match was created",
          format: :"date-time"
        },
        driver: %Schema{
          type: :object,
          oneOf: [Driver],
          description: "The driver assigned to this Match"
        }
      }),
    required: [:origin_address, :destination_address, :service_level, :items],
    example:
      MatchHelper.shared_simple_example(%{
        "id" => "0000c119-fca6-4531-8b7f-716efb54ef26",
        "origin_address" => Address.schema().example,
        "destination_address" => Address.schema().example,
        "driver" => nil,
        "distance" => 20.1,
        "total_price" => 62.00,
        "price" => 40.00,
        "tip_price" => 10.00,
        "load_fee_price" => 12.00,
        "scheduled" => true,
        "shortcode" => "ABCDEFGH",
        "recipient" => %{
          "name" => "John Smith",
          "phone" => "+18000000000",
          "email" => "john@smith.com",
          "notify" => false
        },
        "total_weight" => 250,
        "total_volume" => 12_345,
        "inserted_at" => "2030-01-01T00:19:50Z"
      })
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.MatchRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{MatchStopItem, MatchHelper}

  OpenApiSpex.schema(%{
    title: "MatchRequest",
    description: "POST body for creating a Match",
    type: :object,
    properties:
      MatchHelper.shared_simple_props(%{
        origin_address: %Schema{type: :string, description: "The pickup point for this Match"},
        destination_address: %Schema{
          type: :string,
          description: "The dropoff point for this Match"
        },
        shipper_email: %Schema{
          type: :string,
          description: "Email of shipper this Match should belong to if other than the default.",
          nullable: true
        },
        recipient_name: %Schema{
          type: :string,
          description: "Name of this Stop's recipient",
          nullable: true
        },
        recipient_phone: %Schema{
          type: :string,
          description: "Phone number of this Match's recipient",
          nullable: true
        },
        recipient_email: %Schema{
          type: :string,
          format: :email,
          description: "Email of this Match's recipient",
          nullable: true
        },
        notify_recipient: %Schema{
          type: :boolean,
          default: true,
          description:
            "Set to `false` if the recipient should not receive SMS notifications regarding the status of their shipment"
        },
        tip: %Schema{
          type: :integer,
          default: 0,
          description: "Additional tip for the driver in US cents (¢)"
        },
        items: %Schema{
          type: :array,
          minItems: 1,
          items: MatchStopItem,
          description: "Items to be delivered"
        }
      }),
    required: [:origin_address, :destination_address, :service_level, :items],
    example:
      MatchHelper.shared_simple_example(%{
        "origin_address" => "708 Walnut St. Cincinnati, OH 45202",
        "destination_address" => "708 Walnut St. Cincinnati, OH 45202",
        "shipper_email" => "joe@smith.com",
        "recipient_name" => "John Smith",
        "recipient_phone" => "+18000000000",
        "recipient_email" => "john@smith.com",
        "notify_recipient" => false,
        "tip" => 10_00,
        "items" => [MatchStopItem.schema().example]
      })
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.SimpleMatchResponse do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas.SimpleMatch

  OpenApiSpex.schema(%{
    title: "SimpleMatchResponse",
    description: "Response schema showing only single stop",
    type: :object,
    properties: %{
      response: SimpleMatch
    },
    example: %{
      "response" => SimpleMatch.schema().example
    },
    "x-struct": __MODULE__
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.MatchResponse do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas.Match

  OpenApiSpex.schema(%{
    title: "MatchResponse",
    description: "Response schema showing all stops",
    type: :object,
    properties: %{
      response: Match
    },
    example: %{
      "response" => Match.schema().example
    },
    "x-struct": __MODULE__
  })
end
