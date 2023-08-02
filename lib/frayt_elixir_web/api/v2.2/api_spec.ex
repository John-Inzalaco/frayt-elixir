defmodule FraytElixirWeb.API.V2x2.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server, Components, SecurityScheme}
  alias FraytElixirWeb.Endpoint
  alias FraytElixirWeb.API.V2x2.Router
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Frayt Client API",
        description: """
        <h2>Setup</h2>
        <p>Reach out to the Frayt team to setup an API account at dev@frayt.com. You will be provided with a Client ID + Secret pair that you will use for authentication.</p>
        <h2>Webhooks</h2>
        <p>Webhook payloads are defined in the callbacks of each method below. You can find detailed state information under the response Schema of each callback.</p>
        <p><i>To receive webhook updates from Frayt, contact the Frayt team for setup and configuration at dev@frayt.com</i></p>
        """,
        version: "2.2"
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{"authorization" => %SecurityScheme{type: "http", scheme: "bearer"}}
      }
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
