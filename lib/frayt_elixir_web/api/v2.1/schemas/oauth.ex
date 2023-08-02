defmodule FraytElixirWeb.API.V2x1.Schemas.OauthParams do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Oauth Request",
    description: "Company Oauth credentials",
    type: :object,
    properties: %{
      client_id: %Schema{type: :string},
      secret: %Schema{type: :string}
    },
    required: [:client_id, :secret],
    example: %{
      "client_id" => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "secret" => "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    }
  })
end

defmodule FraytElixirWeb.API.V2x1.Schemas.OauthResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Oauth Response",
    description: "Company Oauth credentials",
    type: :object,
    properties: %{
      response: %Schema{
        type: :object,
        properties: %{token: %Schema{type: :string}}
      }
    },
    required: [:client_id, :secret],
    example: %{
      "response" => %{
        "token" => "xxxxxx..."
      }
    }
  })
end
