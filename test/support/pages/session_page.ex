defmodule FraytElixirWeb.Test.SessionPage do
  use Wallaby.DSL
  import Wallaby.Query

  def visit_page(session, page \\ nil) do
    session |> visit("http://localhost:4002/#{page}")
  end

  def enter_credentials(session, email, password) do
    session
    |> fill_in(text_field("session[email]"), with: email)
    |> fill_in(text_field("session[password]"), with: password)
    |> click(css(".session__submit"))
  end
end
