defmodule FraytElixirWeb.API.V2x1.Schemas.Shipper do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Shipper",
    description: "A Shipper",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Unique identifier for shipper"},
      phone: %Schema{type: :string, description: "Phone number"},
      first_name: %Schema{type: :string},
      last_name: %Schema{type: :string},
      email: %Schema{type: :string, format: :email, description: "Email associated with Shipper"}
    },
    example: %{
      id: "0ff660a4-4866-4382-a008-c942d33e0cb6",
      phone: "+18000000000",
      first_name: "Billy",
      last_name: "Bob",
      email: "billy@bob.com"
    }
  })
end
