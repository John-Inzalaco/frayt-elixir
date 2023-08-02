defmodule FraytElixirWeb.API.V2x1.Schemas.InvalidParameters do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Invalid Parameters",
    description: "Error response when invalid paramaters are passed",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            title: %Schema{type: :string},
            source: %Schema{type: :object, properties: %{pointer: %Schema{type: :string}}},
            detail: %Schema{type: :string}
          }
        }
      }
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.UnprocessibleEntity do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas

  OpenApiSpex.schema(%{
    title: "Unprocessible Entity",
    description: "Error response when problematic params are passed",
    type: :object,
    properties: Schemas.error_code_properties(),
    example: %{
      "code" => "unprocessible_entity",
      "message" => "string"
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.Unauthorized do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas

  OpenApiSpex.schema(%{
    title: "Unauthorized",
    description: "No credentials were provided",
    type: :object,
    properties: Schemas.error_code_properties(),
    example: %{
      code: "unauthenticated",
      message: "You are not logged in"
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.Forbidden do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas

  OpenApiSpex.schema(%{
    title: "Forbidden",
    description: "Invalid/expired credentials were provided or permissions are insufficient",
    type: :object,
    properties: Schemas.error_code_properties(),
    example: %{
      "code" => "forbidden",
      "message" => "string"
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.NotFound do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas

  OpenApiSpex.schema(%{
    title: "Not Found",
    description: "Unable to find resource",
    type: :object,
    properties: Schemas.error_code_properties(),
    example: %{
      "code" => "not_found",
      "message" => "Not Found"
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.BadRequest do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas

  OpenApiSpex.schema(%{
    title: "Bad Request",
    description: "There is an issue with you request",
    type: :object,
    properties: Schemas.error_code_properties()
  })
end
