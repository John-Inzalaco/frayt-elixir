import Config

# Configure your database
config :frayt_elixir, FraytElixir.Repo,
  database: "frayt_elixir_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  queue_target: 3000

config :frayt_elixir,
  bringg_client: FraytElixir.Test.FakeBringg

config :frayt_elixir, FraytElixir.Branch, api_caller: &FraytElixir.Test.FakeBranch.call_api/4

config :frayt_elixir, FraytElixir.Screenings.Turn,
  api_caller: &FraytElixir.Test.FakeTurn.call_api/4

config :frayt_elixir, FraytElixir.ExHubspot, api_caller: &FraytElixir.Test.FakeHubspot.call_api/4

config :frayt_elixir, FraytElixir.TollGuru, api_caller: &FraytElixir.Test.FakeTollGuru.call_api/3

config :frayt_elixir, FraytElixir.TomTom,
  optimization_api_caller: FraytElixir.Test.TomTom.FakeWaypointOptimization

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :frayt_elixir, FraytElixirWeb.Endpoint,
  http: [port: 4002],
  server: true

config :frayt_elixir, :sandbox, Ecto.Adapters.SQL.Sandbox

# Print only warnings and errors during test
config :logger, level: :warn

config :frayt_elixir, FraytElixir.Notifications.Slack,
  send_message: &FraytElixir.Test.FakeSlack.send_message!/3

config :frayt_elixir, FraytElixir.MatchSupervisor,
  slack_notification_interval: 100,
  slack_max_notification_interval: 600,
  driver_notification_interval: 100,
  init_unaccepted_match_notifiers_delay: 0

config :frayt_elixir, FraytElixir.Shipment.IdleDriverNotifier,
  short_notice_interval: 1000,
  short_notice_time: 2000,
  scheduled_alert_interval: 1750,
  warning_interval: 1000,
  cancel_interval: 1000

config :frayt_elixir, FraytElixir.Shipment.ETAPoller, interval: 30 * 1000

config :frayt_elixir, FraytElixir.Shipment.DeliveryBatchRouter,
  poll_interval: 100,
  routific: FraytElixir.Test.FakeRoutific

config :frayt_elixir, FraytElixir.Payments,
  stripe_invoice_customer: "cus_12345",
  stripe_invoice_card: "card_12345",
  payment_provider: FraytElixir.Test.FakeStripe,
  screening_provider: FraytElixir.Test.FakeTurn,
  authorize_match: &FraytElixir.Test.FakePayments.authorize_match/2

config :frayt_elixir,
  branch_aes_key: "nZFF/qfwDZVjDFlPbxAkR6tddG6zL2ytim/46HwtIM0=",
  api_version: "2.1",
  hubspot_webhook_api_key: "valid_hubspot_webhook_api_key",
  child_processes: [
    {FraytElixir.Test.FakeSlack, name: FraytElixir.Test.FakeSlack},
    {FraytElixir.Test.FakeRoutific, name: FraytElixir.Test.FakeRoutific}
  ],
  geocoder: &FraytElixir.Test.FakeGeo.geocode/1,
  timezone_finder: &FraytElixir.Test.FakeTimezone.timezone/2,
  distance_calculator: &FraytElixir.Test.FakeGeo.distance/2,
  photo_url_generator: &FraytElixir.Test.FakeS3.s3_presigned_url/1,
  sql_sandbox: true,
  push_notification: FraytElixir.Test.FakePushNotification,
  sms_notification: &FraytElixir.Test.FakeTwilio.send_message/1,
  hash_password: &FraytElixir.Test.FakePassword.hash_password/2,
  check_password: &FraytElixir.Test.FakePassword.check_password/3,
  generate_client_and_secret: &FraytElixir.Test.FakeApiAccount.generate_client_and_secret/1,
  fetch: &FraytElixir.Test.FakeImport.fetch/1,
  enable_multistop_ui: true,
  get_time_surcharge: &FraytElixir.Test.FakeTimeSurcharge.get_time_surcharge/2

config :wallaby,
  driver: Wallaby.Chrome,
  # chromedriver: [
  #   headless: false
  # ],
  js_errors: false,
  screenshot_on_failure: true,
  max_wait_time: 3_000

config :frayt_elixir, FraytElixir.Mailer, adapter: Bamboo.TestAdapter

config :waffle,
  storage: Waffle.Storage.Local

config :frayt_elixir, FraytElixir.Accounts.Webhook,
  socks_host: "",
  socks_user: "",
  socks_pass: ""

config :frayt_elixir, Oban, testing: :inline
config :appsignal, :config, active: false

config :frayt_elixir, FraytElixir.Notifications.Zapier, base_url: "http://localhost:9081/zapier/"

config :mock_me, port: 9081

if File.exists?("config/test.secret.exs") do
  import_config "test.secret.exs"
end
