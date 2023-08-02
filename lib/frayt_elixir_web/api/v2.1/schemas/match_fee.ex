defmodule FraytElixirWeb.API.V2x1.Schemas.MatchFee do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MatchFee",
    description: "A fee associated with a Match that is charged to the shipper",
    type: :object,
    properties: %{
      id: %Schema{type: :string},
      description: %Schema{type: :string},
      name: %Schema{type: :string, description: "Human readable name of fee"},
      type: %Schema{type: :string, description: "Computer friendly type of fee"},
      amount: %Schema{type: :integer, description: "Fee amount in US cents (¢)"}
    },
    example: %{
      "amount" => 4661,
      "description" => nil,
      "id" => "1e261ee8-71b3-480a-908d-168941ccea05",
      "name" => "Base Fee",
      "type" => "base_fee"
    }
  })
end
