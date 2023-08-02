defmodule FraytElixirWeb.Hubspot.AccountController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Hubspot
  alias FraytElixir.Hubspot.Account

  action_fallback(FraytElixirWeb.FallbackController)

  plug(:put_layout, "unauthenticated.html")

  def new(conn, %{"code" => code}) do
    {title, message} =
      case Hubspot.setup_account(code) do
        {:ok, %Account{}} ->
          {"Hooray!", "Successfully added Frayt to your Hubspot integration"}

        {:error, %{"status" => "BAD_AUTH_CODE"}} ->
          {"An Error Occurred",
           "It appears this link has expired. Try adding Frayt to your Hubspot account again."}

        {:error, %{"status" => "MISMATCH_REDIRECT_URI_AUTH_CODE"}} ->
          {"An Error Occurred",
           "It appears that there is an issue with the redirect URI. Contact support at development@frayt.com"}
      end

    render(conn, "new.html", title: title, message: message)
  end
end
