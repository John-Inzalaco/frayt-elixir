defmodule FraytElixirWeb.API.V2x2.Schemas.AddressRequest do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas.Address
  import FraytElixir.AtomizeKeys

  address_schema = Address.schema()

  @required [:address, :city, :state_code, :zip, :country_code, :lat, :lng]

  @shared [:address2, :neighborhood, :name] ++ @required

  @props Map.take(address_schema.properties, @shared)

  @example address_schema.example
           |> atomize_keys()
           |> Map.take(@shared)
           |> Map.put(:name, "Frayt HQ")

  OpenApiSpex.schema(%{
    title: "AddressRequest",
    description: "A Goecoded address",
    type: :object,
    properties: @props,
    required: @required,
    example: @example
  })
end
