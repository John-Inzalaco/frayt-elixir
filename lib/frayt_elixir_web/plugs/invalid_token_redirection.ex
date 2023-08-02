defmodule FraytElixirWeb.Plugs.InvalidTokenRedirection do
  import Plug.Conn
  import Guardian.Plug.Keys

  alias Guardian.Plug.Pipeline

  def init(default), do: default

  def call(conn, opts) do
    if Guardian.Plug.session_active?(conn) do
      with nil <- Guardian.Plug.current_token(conn, opts),
           {:ok, token} <- find_token_from_session(conn, opts),
           module <- Pipeline.fetch_module!(conn, opts),
           claims_to_check <- Keyword.get(opts, :claims, %{}),
           {:ok, _claims} <- Guardian.decode_and_verify(module, token, claims_to_check, opts) do
        conn
      else
        {:error, _reason} ->
          FraytElixirWeb.Plugs.Auth.browser_sign_out(conn)

        _ ->
          conn
      end
    else
      conn
    end
  end

  defp find_token_from_session(conn, opts) do
    key = conn |> storage_key(opts) |> token_key()
    token = get_session(conn, key)
    if token, do: {:ok, token}, else: :no_token_found
  end

  defp storage_key(conn, opts), do: Pipeline.fetch_key(conn, opts)
end
