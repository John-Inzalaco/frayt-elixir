defmodule FraytElixirWeb.Plugs.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  match("/api/v2.1/*_", to: FraytElixirWeb.API.V2x1.Router)
  match("/api/v2.2/*_", to: FraytElixirWeb.API.V2x2.Router)
  match(_, to: FraytElixirWeb.Router)
end
