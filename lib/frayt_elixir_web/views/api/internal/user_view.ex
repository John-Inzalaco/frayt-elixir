defmodule FraytElixirWeb.API.Internal.UserView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.UserView

  def render("index.json", %{users: users}) do
    %{data: render_many(users, UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{response: render_one(user, UserView, "user.json")}
  end

  def render("error.json", %{message: message}) do
    %{
      error: message
    }
  end

  def render("user.json", %{user: user}) do
    %{id: user.id, email: user.email}
  end
end
