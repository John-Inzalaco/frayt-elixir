defmodule FraytElixirWeb.Plugs.RateLimiter do
  use Plug.Builder

  if Application.get_env(:frayt_elixir, :environment) == :prod do
    plug Hammer.Plug,
      rate_limit: {"by_ip", 1_000, 20},
      by: :ip

    plug Hammer.Plug,
      rate_limit: {"by_token", 1_000, 20},
      by: {:conn, &Guardian.Plug.current_resource/1},
      when_nil: :pass
  end
end
