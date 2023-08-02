defmodule FraytElixirWeb.API.V2x1.Schemas.Address do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  @props %{
    formatted_address: %Schema{
      type: :string,
      description: "Combined address components in a human readable string"
    },
    lat: %Schema{type: :number, format: :float, description: "Latitude point of address"},
    lng: %Schema{type: :number, format: :float, description: "Longitude point of address"},
    address: %Schema{type: :string, description: "Address line 1"},
    address2: %Schema{type: :string, description: "Address line 2"},
    city: %Schema{type: :string, description: "City"},
    state: %Schema{type: :string, description: "Full state name"},
    state_code: %Schema{type: :string, description: "State code (e.g. OH)"},
    zip: %Schema{type: :string, description: "Zipcode"},
    country_code: %Schema{type: :string, description: "Country"},
    neighborhood: %Schema{
      type: :string,
      description: "The general neighborhood the address is located in"
    },
    name: %Schema{
      type: :string,
      description:
        "The name of this address. This could be a store name, a park, or any other name"
    }
  }

  @example %{
    "formatted_address" => "708 Walnut Street 500, Cincinnati, Ohio 45202",
    "lat" => 39.1043198,
    "lng" => -84.5118912,
    "address" => "708 Walnut Street",
    "address2" => "500",
    "city" => "Cincinnati",
    "state" => "Ohio",
    "state_code" => "OH",
    "zip" => "45202",
    "country" => "United States",
    "neighborhood" => "Central Business District",
    "country_code" => "US",
    "name" => nil
  }

  OpenApiSpex.schema(%{
    title: "Address",
    description: "A Goecoded address",
    type: :object,
    properties: @props,
    example: @example
  })
end
