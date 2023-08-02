defmodule FraytElixirWeb.Authorize do
  def init(opts) do
    opts
    |> Keyword.put_new(:action, {Phoenix.Controller, :action_name})
    |> Keyword.put_new(:user, {FraytElixirWeb.SessionHelper, :get_current_driver})
    |> Keyword.put_new(:fallback, FraytElixirWeb.FallbackController)
    |> Bodyguard.Plug.Authorize.init()
  end

  def call(conn, opts) do
    Bodyguard.Plug.Authorize.call(conn, opts)
  end
end
