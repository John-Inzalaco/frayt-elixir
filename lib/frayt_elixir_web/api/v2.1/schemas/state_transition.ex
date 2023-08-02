defmodule FraytElixirWeb.API.V2x1.Schemas.StateTransition do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StateTransition",
    description: "Details regarding a record's transition from one state to another",
    type: :object,
    properties: %{
      notes: %Schema{
        type: :string,
        description: "Notes contain additional information regarding the state transition."
      },
      to: %Schema{type: :string, description: "State that the record transitioned to"},
      from: %Schema{type: :string, description: "State that the record transitioned from"},
      updated_at: %Schema{
        type: :string,
        description: "Date & time of state transition",
        format: :"date-time"
      }
    },
    example: %{
      "notes" => nil,
      "to" => "routing",
      "from" => "pending",
      "updated_at" => "2030-01-01 09:30:00"
    }
  })
end
