defmodule FraytElixirWeb.Admin.BatchView do
  use FraytElixirWeb, :view
  import Phoenix.HTML.Form
  import FraytElixirWeb.DisplayFunctions

  alias FraytElixir.Repo
  alias FraytElixir.Accounts.ApiAccount

  def api_accounts do
    case Repo.all(ApiAccount) do
      [] ->
        []

      accounts ->
        accounts |> Repo.preload(:company)
    end
  end
end
