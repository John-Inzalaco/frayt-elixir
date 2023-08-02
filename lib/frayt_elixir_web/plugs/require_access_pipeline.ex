defmodule FraytElixirWeb.Plugs.RequireAccessPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :frayt_elixir,
    error_handler: FraytElixir.AuthErrorHandler

  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.VerifyHeader
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, ensure: true
end
