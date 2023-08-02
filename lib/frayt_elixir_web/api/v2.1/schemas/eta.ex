defmodule FraytElixirWeb.API.V2x1.Schemas.ETA do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ETA",
    description: "Estimated Time of Arrival",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Unique identifier for ETA"},
      arrive_at: %Schema{
        type: :string,
        description: "Date & time of arrival",
        format: :"date-time"
      }
    },
    example: %{
      "id" => "1e261ee8-71b3-480a-908d-168941ccea05",
      "arrive_at" => "2022-10-01 11:45:10"
    }
  })
end
