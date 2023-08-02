defmodule FraytElixir.Repo do
  use Ecto.Repo,
    otp_app: :frayt_elixir,
    adapter: Ecto.Adapters.Postgres

  use ExAudit.Repo
end
