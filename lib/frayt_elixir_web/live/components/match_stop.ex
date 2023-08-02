defmodule FraytElixirWeb.LiveComponent.MatchStop do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("_match_stop.html", assigns)
  end
end
