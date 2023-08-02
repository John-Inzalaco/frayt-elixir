defmodule FraytElixirWeb.Plugs.AuditUser do
  alias FraytElixirWeb.Plugs.Auth
  alias FraytElixir.Accounts.User

  def init(default), do: default

  def call(conn, _) do
    case Auth.current_user(conn) do
      %User{id: user_id} -> ExAudit.track(user_id: user_id)
      _ -> nil
    end

    conn
  end
end
