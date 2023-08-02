defmodule FraytElixirWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :frayt_elixir
  use Appsignal.Phoenix

  if sandbox = Application.get_env(:frayt_elixir, :sandbox) do
    plug Phoenix.Ecto.SQL.Sandbox, sandbox: sandbox
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: FraytElixirWeb.NebulexSession,
    pub_sub: FraytElixir.PubSub,
    key: "_frayt_elixir_key",
    signing_salt: "duSiDyur",
    lifetime: 14 * 24 * 60 * 60 * 1000
  ]

  socket "/socket", FraytElixirWeb.UserSocket,
    websocket: [
      serializer: [
        {FraytElixirWeb.UserSocket.Serializer, "2.0.0"}
      ]
    ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:user_agent, session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :frayt_elixir,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  plug Plug.Static, at: "/uploads", from: Path.expand('./uploads'), gzip: false

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 120_000_000

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug CORSPlug, origin: "*"

  # plug FraytElixirWeb.Router
  plug FraytElixirWeb.Plugs.Router
end
