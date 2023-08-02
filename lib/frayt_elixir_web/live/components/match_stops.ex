defmodule FraytElixirWeb.LiveComponent.MatchStops do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("_match_stops.html", assigns)
  end
end
