defmodule FraytElixirWeb.API.V2x1.Schemas.Driver do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Driver",
    description: "A Driver",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Unique identifier for driver"},
      email: %Schema{type: :string, format: :email, description: "Email associated with driver"},
      phone_number: %Schema{type: :string, description: "Driver's phone number"},
      first_name: %Schema{type: :string},
      last_name: %Schema{type: :string},
      vehicle_make: %Schema{type: :string, description: "Make of the driver's vehicle"},
      vehicle_model: %Schema{type: :string, description: "Model of the driver's vehicle"},
      vehicle_year: %Schema{
        type: :string,
        description: "Manufacturing year of the driver's vehicle"
      },
      vehicle_class: %Schema{
        type: :integer,
        enum: [1, 2, 3]
      },
      current_location: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, description: "Unique identifier for driver's location"},
          lat: %Schema{
            type: :number,
            format: :float,
            description: "Latitude point of driver's location"
          },
          lng: %Schema{
            type: :number,
            format: :float,
            description: "Longitude point of driver's location"
          },
          created_at: %Schema{
            type: :string,
            description: "Date & time of last driver location update",
            format: :"date-time"
          }
        }
      }
    },
    example: %{
      "id" => "0ff660a4-4866-4382-a008-c942d33e0cb6",
      "email" => "bob@smith.co",
      "phone_number" => "+19998887777",
      "first_name" => "Bob",
      "last_name" => "Smith",
      "vehicle_make" => "Tesla",
      "vehicle_model" => "Cybertruck",
      "vehicle_year" => "2022",
      "vehicle_class" => 2,
      "current_location" => %{
        "id" => "00021f0f-0ccb-4773-8983-4cb4ef519fab",
        "lat" => 39.109793,
        "lng" => -84.515256,
        "created_at" => "2020-09-28T09:31"
      }
    }
  })
end
