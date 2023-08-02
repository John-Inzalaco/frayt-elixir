defmodule FraytElixirWeb.OauthView do
  use FraytElixirWeb, :view

  def render("authenticate.json", %{token: token}) do
    %{
      response: %{
        token: token
      }
    }
  end

  def render("error.json", %{message: message}) do
    %{
      error: %{
        message: message
      }
    }
  end
end
