# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :frayt_elixir, FraytElixir.Holistics, api_url: "https://us.holistics.io"

config :frayt_elixir, FraytElixir.ExHubspot, api_url: "https://api.hubapi.com"

config :frayt_elixir,
  walmart_consumer_id:
    System.get_env("WALMART_CONSUMER_ID", "9f3c52c5-72ea-44b7-9edc-66a1799b4faf"),
  walmart_key_version: System.get_env("WALMART_KEY_VERSION", "1"),
  walmart_private_pem: System.get_env("WALMART_PRIVATE_PEM", nil),
  walmart_private_pem_file_location:
    System.get_env(
      "WALMART_PRIVATE_PEM_FILE_PATH",
      ""
    ),
  walmart_webhook_url:
    System.get_env(
      "WALMART_API_URL",
      "https://developer.api.us.stg.walmart.com/api-proxy/service/csp-webhook/service/v1/api/webhook/dsp"
    ),
  walmart_client_id: System.get_env("WALMART_CLIENT_ID", "frayt")

config :frayt_elixir,
  bringg_admin_client_id: System.get_env("BRINGG_ADMIN_CLIENT_ID"),
  bringg_admin_client_secret: System.get_env("BRINGG_ADMIN_CLIENT_SECRET"),
  bringg_self_fleet_uuid: System.get_env("BRINGG_SELF_FLEET_UUID"),
  bringg_api_url: System.get_env("BRINGG_API_URL", "https://us2-admin-api.bringg.com"),
  bringg_client: FraytElixir.Integrations.BringgApi

config :frayt_elixir, FraytElixir.MatchSupervisor,
  unscheduled_delay: 60 * 60 * 1000,
  driver_distance_increment: 5,
  final_distance_increment: 10,
  driver_notification_interval: 60 * 1000,
  slack_notification_interval: 10 * 1000,
  slack_max_notification_interval: 40 * 1000,
  init_unaccepted_match_notifiers_delay: 2 * 60 * 1_000

config :frayt_elixir, FraytElixir.Shipment.DeliveryBatchRouter, poll_interval: 1000

config :frayt_elixir, FraytElixir.Shipment.IdleDriverNotifier,
  short_notice_interval: 30 * 1000,
  short_notice_time: 30 * 60_000,
  scheduled_alert_interval: 30 * 60_000,
  warning_interval: 15 * 60_000,
  cancel_interval: 5 * 60_000

config :frayt_elixir, FraytElixir.Shipment.ETAPoller, interval: 30 * 1000

config :frayt_elixir, FraytElixir.Notifications.Slack,
  ops_id: System.get_env("SLACK_OPS_GROUP_ID", "S01FJN1Q62F"),
  sales_id: System.get_env("SLACK_SALES_ID", "S01FQFMSYPN"),
  dispatch_channel: System.get_env("SLACK_DISPATCH_CHANNEL", "#test-dispatch"),
  dispatch_attempts_channel:
    System.get_env("SLACK_DISPATCH_ATTEMPTS_CHANNEL", "#test-dispatch-attempts"),
  high_priority_dispatch_channel:
    System.get_env("SLACK_HIGH_PRIORITY_DISPATCH_CHANNEL", "#test-high-priority-dispatch"),
  emails_channel: System.get_env("SLACK_EMAILS_CHANNEL", "#test-emails"),
  drivers_channel: System.get_env("SLACK_DRIVERS_CHANNEL", "#test-drivers"),
  shippers_channel: System.get_env("SLACK_SHIPPERS_CHANNEL", "#test-shippers"),
  sales_channel: System.get_env("SLACK_SALES_CHANNEL", "#sales-test"),
  payments_channel: System.get_env("SLACK_PAYMENTS_CHANNEL", "#payments-test"),
  appsignal_channel: System.get_env("SLACK_APPSIGNAL_CHANNEL", "#test-appsignal"),
  errors_channel: System.get_env("SLACK_ERROR_CHANNEL", "#test-errors")

config :frayt_elixir, FraytElixir.TomTom,
  api_key: System.get_env("TOMTOM_API_KEY"),
  api_url: "https://api.tomtom.com/"

config :frayt_elixir, FraytElixir.TollGuru,
  api_key: System.get_env("TOLLGURU_API_KEY"),
  api_url: "https://dev.TollGuru.com/v1/calc"

config :frayt_elixir, FraytElixir.Branch,
  api_url: "https://sandbox.branchapp.com/v1/",
  api_key: System.get_env("BRANCH_API_KEY"),
  org_id: System.get_env("BRANCH_ORG_ID")

config :frayt_elixir, FraytElixir.Screenings.Turn,
  base_url:
    System.get_env("TURN_BASE_URL", "https://stoplight.io/mocks/turnhq/turn-api/16101592/"),
  screening_package: System.get_env("TURN_SCREENING_PACKAGE"),
  api_key: System.get_env("TURN_API_KEY")

config :frayt_elixir, FraytElixir.CustomContracts.ContractFees,
  default_preferred_driver_fee: System.get_env("DEFAULT_PREFERRED_DRIVER_FEE", "0.05")

config :frayt_elixir,
  ecto_repos: [FraytElixir.Repo],
  support_email: "support@frayt.com",
  notifications_email: "notifications@frayt.com",
  shipper_portal_url: "http://localhost:3000"

config :frayt_elixir, FraytElixir.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5560,
  types: FraytElixir.PostgresTypes,
  extensions: [{Geo.PostGIS.Extension, library: Geo}]

# Configures the endpoint
config :frayt_elixir, FraytElixirWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "h6eUzzTsUORRVnxGe3S61pyAbSimpxALUcslDKGSZHmnBKP+MPvDnmXxGjw2riPq",
  render_errors: [view: FraytElixirWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: FraytElixir.PubSub,
  live_view: [signing_salt: "cVf1hf0r"]

config :frayt_elixir, FraytElixir.Guardian,
  issuer: "https://frayt.com",
  secret_key: "3JJ1BM0xgQI7W3D0Ln6GJxTldQM9vCny1WxP/Zb/R8CsmwUhwb0yWhYlY1IuhzAy"

config :frayt_elixir, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      # phoenix routes will be converted to swagger paths
      router: FraytElixirWeb.Router
    ]
  }

config :frayt_elixir,
  environment: config_env(),
  frayt_phone_number: "+15132764438",
  branch_aes_key: System.get_env("BRANCH_AES_KEY")

config :google_maps,
  api_key: System.get_env("GOOGLE_API_KEY")

config :stripity_stripe, api_key: System.get_env("STRIPE_SECRET")

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :webhook, :webhook_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :geo_postgis,
  json_library: Jason

config :ueberauth, Ueberauth,
  base_path: "/api/internal/v2/auth",
  providers: [
    identity:
      {Ueberauth.Strategy.Identity,
       [
         callback_methods: ["POST"],
         nickname_field: :email,
         uid_field: :username
       ]}
  ]

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000, cleanup_interval_ms: 60_000 * 10]}

config :frayt_elixir, FraytElixirWeb.Plugs.RequireAccessPipeline, module: FraytElixir.Guardian

config :guardian, Guardian.DB, repo: FraytElixir.Repo

config :hound, driver: "chrome_driver", browser: "chrome_headless"

config :ex_audit,
  version_schema: FraytElixir.Version,
  tracked_schemas: [
    FraytElixir.Shipment.Match,
    FraytElixir.Drivers.Driver,
    FraytElixir.Payments.PaymentTransaction,
    FraytElixir.Shipment.MatchStop,
    FraytElixir.Shipment.Address,
    FraytElixir.Shipment.MatchFee
  ],
  primitive_structs: [
    Date,
    DateTime,
    NaiveDateTime
  ]

config :routific,
  api_token: System.get_env("ROUTIFIC_API_KEY")

config :appsignal, :config,
  otp_app: :frayt_elixir,
  name: "frayt-elixir",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY"),
  env: config_env(),
  active: true

config :libcluster,
  topologies: [
    example: [
      strategy: Cluster.Strategy.Gossip
    ]
  ]

config :frayt_elixir, Oban,
  repo: FraytElixir.Repo,
  notifier: Oban.Notifiers.PG,
  plugins: [
    Oban.Plugins.Gossip,
    Oban.Plugins.Lifeline,
    {Oban.Plugins.Pruner, max_age: 15 * 60},
    {Oban.Plugins.Cron,
     crontab: [
       {"@hourly", FraytElixir.Workers.DriverMetricsUpdater},
       {"@hourly", FraytElixir.Workers.CompanyMetricsUpdater},
       {"@hourly", FraytElixir.Workers.PaymentRunner},
       # run after every 10 mins
       {"*/10 * * * *", FraytElixir.Workers.MatchScheduler},
       {"@monthly", FraytElixir.Workers.MonthlyMigrations}
     ]}
  ],
  queues: [metrics: 1, payments: 1, maintenance: 1, default: 1]

config :frayt_elixir, FraytElixir.Cache,
  model: :inclusive,
  levels: [
    {
      FraytElixir.Cache.L1,
      gc_interval: 3_600_000, backend: :shards
    },
    {
      FraytElixir.Cache.L2,
      primary: [
        gc_interval: 3_600_000,
        backend: :shards
      ]
    }
  ]

config :bodyguard,
  default_error: :unauthorized

config :frayt_elixir, FraytElixir.Notifications.Zapier,
  webhooks: [
    match_status: "hooks/catch/2625948/3tw9j04/"
  ]

config(:fun_with_flags, :cache_bust_notifications, enabled: false)

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: FraytElixir.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
