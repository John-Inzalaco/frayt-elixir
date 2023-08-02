defmodule FraytElixir.AuthErrorHandler do
  use FraytElixirWeb, :controller

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    FraytElixirWeb.FallbackController.call(conn, {:error, type})
  end
end
