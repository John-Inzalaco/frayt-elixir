defmodule FraytElixirWeb.API.V2x1.Schemas.BatchResponse do
  require OpenApiSpex
  # alias OpenApiSpex.Schema
  alias FraytElixirWeb.API.V2x1.Schemas.Batch

  OpenApiSpex.schema(%{
    title: "BatchResponse",
    description: "Response schema for batch",
    type: :object,
    properties: %{
      response: Batch
    },
    example: %{
      "response" => Batch.schema().example
    },
    "x-struct": __MODULE__
  })
end
