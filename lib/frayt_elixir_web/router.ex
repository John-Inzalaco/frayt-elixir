defmodule FraytElixirWeb.Router do
  use FraytElixirWeb, :router

  import Phoenix.LiveDashboard.Router

  alias FraytElixirWeb.Plugs.{CheckAdmin, RequireAccessPipeline, AuditUser, Version, RateLimiter}
  alias FraytElixirWeb.SessionHelper

  use Plug.ErrorHandler
  use Sentry.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ProperCase.Plug.SnakeCaseParams

    plug RateLimiter
  end

  pipeline :api_v2 do
    plug Version, %{"" => :v2, ".1" => :V2x1}
  end

  pipeline :authenticated do
    plug RequireAccessPipeline
    plug AuditUser
  end

  pipeline :maybe_authenticated do
    plug Guardian.Plug.Pipeline,
      otp_app: :frayt_elixir,
      module: FraytElixir.Guardian,
      error_handler: FraytElixir.AuthErrorHandler

    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.VerifyHeader
    plug Guardian.Plug.LoadResource, allow_blank: true
  end

  pipeline :admin do
    plug Guardian.Plug.Pipeline,
      otp_app: :frayt_elixir,
      module: FraytElixir.Guardian,
      error_handler: FraytElixirWeb.SessionController

    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.VerifyHeader
    plug Guardian.Plug.EnsureAuthenticated
    plug Guardian.Plug.LoadResource, ensure: true
    plug CheckAdmin
    plug AuditUser
    plug :put_root_layout, {FraytElixirWeb.LayoutView, "root.html"}
  end

  pipeline :openapi do
    plug OpenApiSpex.Plug.PutApiSpec, module: FraytElixirWeb.API.V2x1.ApiSpec
    plug OpenApiSpex.Plug.PutApiSpec, module: FraytElixirWeb.API.V2x2.ApiSpec
  end

  pipeline :invalid_token_redirection do
    plug Guardian.Plug.Pipeline,
      otp_app: :frayt_elixir,
      module: FraytElixir.Guardian,
      error_handler: FraytElixirWeb.SessionController

    plug FraytElixirWeb.Plugs.InvalidTokenRedirection
  end

  if Application.get_env(:frayt_elixir, :environment) == :dev do
    # If using Phoenix
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
    get "/preview_emails/:type", FraytElixirWeb.PreviewEmailController, :show
  end

  redirect "/", "/admin", :permanent

  # Fun With Flags' admin UI must be in a top level scope
  scope path: "/admin/feature_flags" do
    pipe_through [:browser, :maybe_authenticated, :admin]
    forward "/", FunWithFlags.UI.Router, namespace: "admin/feature_flags"
  end

  scope "/", FraytElixirWeb do
    pipe_through :browser
    pipe_through :maybe_authenticated
    get "/admin", SessionController, :new
    get "/sessions", SessionController, :new
    get "/reset-password", SessionController, :reset_password
    get "/sessions/logged-out", SessionController, :logged_out
    delete "/sessions", SessionController, :delete
    get "/sessions/log-out", SessionController, :log_out
    post "/sessions/reset", SessionController, :reset
    post "/sessions", SessionController, :create

    scope "/admin", Admin do
      pipe_through [:admin]

      post "/delivery_batches", DeliveryBatchController, :create

      scope "/markets", as: :report do
        live "/capacity", CapacityLive, :index, session: {SessionHelper, :build_live_session, []}

        live "/dashboard", MarketsDashboardLive, :dashboard,
          session: {SessionHelper, :build_live_session, []}
      end

      post "/drivers/:driver_id/vehicles/:vehicle_id/photos", DriversController, :vehicle_photos
      post "/drivers/:id/photos", DriversController, :driver_photos

      live_dashboard "/dashboard"

      live "/matches", MatchesLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/batches", BatchesLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/matches/create", CreateMatchLive, :create,
        session: {SessionHelper, :build_live_session, []}

      live "/matches/multistop", CreateMultistopLive, :create,
        session: {SessionHelper, :build_live_session, []}

      live "/matches/:id", MatchDetailsLive, :add,
        session: {SessionHelper, :build_live_session, []}

      live "/companies", CompaniesLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/companies/:id", CompanyDetailsLive, :details,
        session: {SessionHelper, :build_live_session, []}

      live "/companies/:company_id/locations/:location_id", LocationDetailsLive, :details,
        session: {SessionHelper, :build_live_session, []}

      live "/shippers", ShippersLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/drivers", DriversLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/drivers/applicants", ApplicantsLive, :index,
        session: {SessionHelper, :build_live_session, []}

      live "/drivers/:id", DriverShowLive, :add, session: {SessionHelper, :build_live_session, []}

      live "/settings/:setting_page", SettingsLive, :index,
        session: {SessionHelper, :build_live_session, []}

      live "/settings/contracts/:id", ContractLive, :index,
        session: {SessionHelper, :build_live_session, []}

      live "/user", SettingsLive, :edit, session: {SessionHelper, :build_live_session, []}

      live "/payments", PaymentsLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/reports", ReportsLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/reports/:id", ReportLive, :index, session: {SessionHelper, :build_live_session, []}

      live "/markets", MarketsLive, :index, session: {SessionHelper, :build_live_session, []}
    end
  end

  scope "/hubspot", FraytElixirWeb, as: :hubspot do
    pipe_through :api

    pipe_through :browser
    resources "/accounts", Hubspot.AccountController, only: [:new]
  end

  scope "/webhooks", FraytElixirWeb.Webhook, as: :webhook do
    pipe_through :api
    post "/hubspot", HubspotController, :handle_webhooks
    post "/branch", BranchController, :handle_webhooks

    post "/turn", TurnController, :handle_webhooks
  end

  scope "/docs/api" do
    get "/v2.1", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/v2.1/openapi",
      default_model_expand_depth: 3

    get "/v2.2", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/v2.2/openapi",
      default_model_expand_depth: 3

    redirect "/favicon-16x16.png", "/favicon.ico", :permanent
    redirect "/favicon-32x32.png", "/favicon.ico", :permanent
  end

  scope "/files", FraytElixirWeb do
    pipe_through :browser

    resources "/agreements", AgreementDocumentController, only: [:show]
  end

  scope "/api/v2/oauth", FraytElixirWeb do
    pipe_through :api
    pipe_through :openapi

    post "/token", OauthController, :authenticate
  end

  scope "/api/v2", FraytElixirWeb do
    pipe_through :api

    get "/estimates/:id", API.MatchController, :show, as: :estimates

    pipe_through :maybe_authenticated
    post "/estimates", API.MatchController, :create_estimate, as: :estimates

    pipe_through :authenticated
    resources "/matches", API.MatchController, as: :api_match
    post "/matches/:id/cancel", API.MatchController, :delete, as: :api_cancel_match
    get "/matches/:id/status", API.MatchController, :status, as: :api_match_status
  end

  scope "/api/v2/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :frayt_elixir,
      swagger_file: "swagger.json"
  end

  scope "/api/internal/v2:version/sessions", FraytElixirWeb, as: :api_v2 do
    pipe_through :api
    pipe_through :api_v2

    post "/shippers", SessionController, :authenticate_shipper
    post "/drivers", SessionController, :authenticate_driver

    pipe_through :authenticated
    delete "/logout", SessionController, :logout
  end

  scope "/api/internal/v2:version", FraytElixirWeb.API.Internal, as: :api_v2 do
    pipe_through :api
    pipe_through :api_v2

    resources "/users", UserController, only: [:create]

    post "/shippers/register", ShipperController, :register

    resources "/markets", MarketController, only: [:index]

    resources "/drivers", DriverController, only: [:create] do
      get "/profile_photo", DriverDocumentController, :profile_photo
      put "/photo", DriverDocumentController, :update_photo
    end

    post "/forgot_password", UserController, :forgot_password

    pipe_through :maybe_authenticated
    resources "/shippers", ShipperController, only: [:create]

    resources "/agreement_documents/:user_type", AgreementDocumentController, only: [:index]

    resources "/matches", MatchController, only: [:create, :update, :show] do
      post "/duplicate", MatchController, :duplicate, as: :action
    end

    resources "/schedules", ScheduleController, only: [:update, :show]

    pipe_through :authenticated

    get "/feature_flags", FeatureFlagController, :show

    resources "/shippers", ShipperController, only: [:update, :index]

    resources "/agreement_documents/:user_type", AgreementDocumentController, only: [:create]

    resources "/driver", DriverController, only: [:update, :show], singleton: true, as: :driver do
      post "/nps_score/:nps_score_id", NpsScoreController, :update

      resources "/locations", DriverLocationController, only: [:create], as: :location

      resources "/devices", DriverDeviceController, only: [:create], as: :device

      resources "/background_checks", BackgroundCheckController,
        only: [:create],
        as: :background_check

      post "/send_test_notification", DriverDeviceController, :send_test_notification

      resources "/vehicles", VehicleController, only: [:create, :update], as: :vehicle do
        patch "/dismiss_capacity", VehicleController, :dismiss_capacity, as: :action
      end

      scope "/reports", as: :report do
        get "/driver_payout_report", DriverReportsController, :payout_report
        get "/driver_payment_history", DriverReportsController, :payment_history
        get "/driver_match_payments", DriverReportsController, :match_payments
        get "/driver_notified_matches", DriverReportsController, :notified_matches
        get "/driver_total_payments", DriverReportsController, :total_payments

        get "/payout", DriverReportsController, :payout_report, as: :type
        get "/history", DriverReportsController, :payment_history, as: :type
        get "/payments", DriverReportsController, :match_payments, as: :type
        get "/matches", DriverReportsController, :notified_matches, as: :type
        get "/total_payments", DriverReportsController, :total_payments, as: :type
      end

      # get "/reports/driver_payout_report", DriverReportsController, :driver_payout_report
      # get "/reports/driver_payment_history", DriverReportsController, :driver_payment_history

      scope "/matches", as: :matches do
        get "/available", DriverMatchController, :available, as: :filter
        get "/missed", DriverMatchController, :missed, as: :filter
        get "/live", DriverMatchController, :live, as: :filter
        get "/completed", DriverMatchController, :completed, as: :filter
      end

      scope "/schedules", as: :schedules do
        get "/available", ScheduleController, :available
      end

      resources "/matches", DriverMatchController, only: [:update, :show], name: :match do
        put "/toggle_en_route", DriverMatchController, :toggle_en_route, as: :action

        resources "/stops", DriverMatchStopController, only: [:update], name: :stop do
          post "/items/:item_id/barcode_readings", BarcodeReadingController, :create,
            as: :item_barcode_reading

          put "/toggle_en_route", DriverMatchStopController, :toggle_en_route, as: :action
        end
      end

      get "/batches/available/:id", DriverMatchController, :available
    end

    post "/reset_password", UserController, :reset_password

    resources "/users", UserController, except: [:create]

    resources "/shipper", ShipperController, only: [:update, :show], singleton: true

    resources "/shipper", ShipperController, only: [], singleton: true, as: :shipper do
      resources "/drivers", ShipperDriverController, only: [:index]
    end

    resources "/matches", MatchController, only: [:index, :delete]

    resources "/addresses", AddressController, only: [:index]

    resources "/credit_cards", CreditCardController, except: [:new, :edit, :show, :index]

    get "/credit_card", CreditCardController, :show

    put "/password", PasswordController, :update
  end

  scope "/api/bringg", FraytElixirWeb do
    pipe_through :api
    post "/matches", Webhook.BringgController, :create
    post "/matches/cancel", Webhook.BringgController, :cancel
    post "/matches/update", Webhook.BringgController, :update
    post "/matches/merchant_registered", Webhook.BringgController, :merchant_registered
  end

  scope "/api/walmart/v1", FraytElixirWeb do
    pipe_through :api
    pipe_through :authenticated
    post "/deliveries", Webhook.WalmartController, :create
    put "/deliveries/:delivery_id/cancel", Webhook.WalmartController, :cancel
    patch "/deliveries/:delivery_id/tip", Webhook.WalmartController, :update_tip
    get "/deliveries/:delivery_id", Webhook.WalmartController, :show
    put "/deliveries/:delivery_id", Webhook.WalmartController, :update
  end

  scope "/", FraytElixirWeb do
    pipe_through :browser
    get "/shippers/:shipper_id/nps/:nps_score_id", NpsScoreController, :show
    post "/shippers/:shipper_id/nps/:nps_score_id", NpsScoreController, :update
  end

  def swagger_description do
    """
    ## Webhooks

    To receive realtime status updates of your matches, we'll need your webhook url and authorization token

    ### Match Transition Payload

    Every time a match transitions to a new state, we send JSON of that match's properties.

    **match** (number)

    **payload_id** (string)
    This is a unique id for the payload being sent. This same id will be used for any retries on failed requests.

    **stage** (number): A match can be in 1 of 14 possible states:

    * -1 = Driver Canceled
    * 0 = Admin Canceled
    * 1 = Canceled
    * 2 = Pending
    * 3 = Scheduled
    * 4 = Assigning Driver
    * 5 = Accepted
    * 6 = En Route To Pickup
    * 7 = Arrived At Pickup
    * 8 = Picked Up
    * 9 = En Route To Dropoff
    * 10 = Arrived At Dropoff
    * 11 = Signed
    * 12 = Delivered
    * 13 = Charged

    **message** (string)

    **status** (string)

    **identifier** (string)

    **receiver_name** (string)

    **picked_up_time** (datetime)

    **delivered_time** (datetime)

    **origin_photo** (string): URL of photo taken of package at the pickup site

    **destination_photo** (string): URL of photo taken of package at the delivery site

    **driver_name** (string)

    **driver_phone** (string)

    **receiver_signature** (string): URL of image of recipient's signature

    **driver_lat** (number)

    **driver_lng** (number)

    ### Driver Location Payload

    When a driver marks in their app that they are en route to the pickup or dropoff sites, we periodically ping for their GPS location and send a JSON payload of their current position.

    **driver_lat** (number)

    **driver_lng** (number)
    """
  end

  def swagger_info do
    %{
      basePath: "/api/v2",
      info: %{
        version: "2",
        title: "Frayt API",
        description: swagger_description()
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header"
        }
      }
    }
  end
end
