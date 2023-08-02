defmodule FraytElixirWeb.API.V2x1.Router do
  use FraytElixirWeb, :router

  alias FraytElixirWeb.Plugs.{RequireAccessPipeline, AuditUser, RateLimiter}

  pipeline :authenticated do
    plug RequireAccessPipeline
    plug AuditUser
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ProperCase.Plug.SnakeCaseParams
    plug OpenApiSpex.Plug.PutApiSpec, module: FraytElixirWeb.API.V2x1.ApiSpec

    plug RateLimiter
  end

  scope "/api/v2.1/swagger" do
    redirect "/index.html", "/docs/api/v2.1", :permanent
    redirect "/", "/docs/api/v2.1", :permanent
  end

  scope "/api/v2.1/openapi" do
    pipe_through :api

    get "/", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api/v2.1/oauth", FraytElixirWeb do
    pipe_through :api

    post "/token", OauthController, :authenticate
  end

  scope "/api/v2.1", FraytElixirWeb.API.V2x1 do
    pipe_through :api
    pipe_through :authenticated

    resources "/matches", MatchController, as: :api_match, only: [:create, :show, :delete]

    post "/matches/estimate", MatchController, :estimate, as: :api_estimate_match

    resources "/batches", BatchController, as: :api_batch, only: [:create, :show, :delete]
  end
end
