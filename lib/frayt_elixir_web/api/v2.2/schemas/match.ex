defmodule FraytElixirWeb.API.V2x2.Schemas.CancelMatchRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CancelMatchRequest",
    description: "DELETE body for canceling a Match",
    type: :object,
    properties: %{
      cancel_reason: %Schema{type: :string, description: "The reason for canceling this Match"}
    },
    example: %{
      "cancel_reason" => "your reason"
    }
  })
end

defmodule FraytElixirWeb.API.V2x2.Schemas.MatchRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{MatchHelper, NewMatchStop}
  alias FraytElixirWeb.API.V2x2.Schemas.AddressRequest

  OpenApiSpex.schema(%{
    title: "MatchRequest",
    description: "POST body for creating a Match",
    type: :object,
    properties:
      MatchHelper.shared_props(%{
        origin_address: %Schema{
          type: :object,
          oneOf: [%Schema{type: :string}, AddressRequest],
          description: "The pickup point for this Match"
        },
        stops: %Schema{description: "Stops", type: :array, minItems: 1, items: NewMatchStop},
        shipper_email: %Schema{
          type: :string,
          description:
            "Email of shipper this Match should created under, if other than the default.",
          nullable: true
        },
        optimize: %Schema{
          type: :boolean,
          description: "Set to true if you want stops to be reordered in the most optimal route"
        }
        # pickup_photo_required: %Schema{
        #   type: :boolean,
        #   description: "Whether a pickup photo is required"
        # }
      }),
    required: [:origin_address, :service_level, :stops],
    example:
      MatchHelper.shared_example(%{
        "origin_address" => AddressRequest.schema().example,
        "stops" => [NewMatchStop.schema().example],
        "optimize" => false
        # "pickup_photo_required" => true
      })
  })
end

defmodule FraytElixirWeb.API.V2x2.Schemas.UpdateMatch do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.{MatchHelper, UpdateMatchStop}

  OpenApiSpex.schema(%{
    title: "UpdateMatch",
    description: "PATCH body for updating a Match that has not been picked up yet.",
    type: :object,
    properties:
      MatchHelper.update_props(%{
        stops: %Schema{description: "Stops", type: :array, minItems: 1, items: UpdateMatchStop}
        # pickup_photo_required: %Schema{
        #   type: :boolean,
        #   description: "Whether a pickup photo is required"
        # }
      }),
    required: [],
    example:
      MatchHelper.update_example(%{
        "stops" => [UpdateMatchStop.schema().example]
        # "pickup_photo_required" => true
      }),
    struct?: false
  })
end

defmodule FraytElixirWeb.API.V2x2.Schemas.MatchResponse do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas.MatchResponse

  match_resp_schema = MatchResponse.schema()

  @example match_resp_schema.example
           |> put_in(["response", "origin_address", "name"], "Frayt HQ")

  @props match_resp_schema.properties

  OpenApiSpex.schema(%{
    title: "MatchResponse",
    description: "Response schema showing all stops",
    type: :object,
    properties: @props,
    example: @example,
    "x-struct": __MODULE__
  })
end

defmodule FraytElixirWeb.API.V2x2.Schemas.MatchEstimateResponse do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x2.Schemas.MatchResponse

  match_resp_schema = MatchResponse.schema()

  @example match_resp_schema.example
           |> put_in(["response", "state"], "pending")

  @props match_resp_schema.properties

  OpenApiSpex.schema(%{
    title: "MatchResponse",
    description:
      "Response schema showing all stops. Estimates do not include the toll costs, if applicable. The exact cost the driver will have to pay in transit will be added to the order instantly upon authorization.",
    type: :object,
    properties: @props,
    example: @example,
    "x-struct": __MODULE__
  })
end

defmodule FraytElixirWeb.API.V2x2.Schemas.UpdateMatchResponse do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x2.Schemas.UpdateMatch

  OpenApiSpex.schema(%{
    title: "UpdateMatchResponse",
    description: "Response schema showing all updated fields, stops, and items",
    type: :object,
    properties: %{
      response: UpdateMatch
    },
    example: %{
      "response" => UpdateMatch.schema().example
    },
    "x-struct": __MODULE__
  })
end
