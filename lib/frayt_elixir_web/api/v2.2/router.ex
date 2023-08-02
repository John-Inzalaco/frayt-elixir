defmodule FraytElixirWeb.API.V2x2.Router do
  use FraytElixirWeb, :router

  alias FraytElixirWeb.Plugs.{RequireAccessPipeline, AuditUser, RateLimiter}

  pipeline :authenticated do
    plug RequireAccessPipeline
    plug AuditUser
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ProperCase.Plug.SnakeCaseParams
    plug OpenApiSpex.Plug.PutApiSpec, module: FraytElixirWeb.API.V2x2.ApiSpec
    plug RateLimiter
  end

  scope "/api/v2.2/openapi" do
    pipe_through :api

    get "/", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api/v2.2/oauth", FraytElixirWeb do
    pipe_through :api

    post "/token", OauthController, :authenticate
  end

  scope "/api/v2.2", FraytElixirWeb.API do
    pipe_through :api
    pipe_through :authenticated

    resources "/matches", V2x2.MatchController,
      as: :api_match,
      only: [:create, :show, :delete]

    patch "/matches/:id", V2x2.UpdateMatchController, :update, as: :api_match
    put "/matches/:id", V2x2.MatchController, :update, as: :api_match

    post "/matches/estimate", V2x2.MatchController, :estimate, as: :api_estimate_match

    resources "/batches", V2x1.BatchController, as: :api_batch, only: [:create, :show, :delete]
  end
end
