defmodule FraytElixirWeb.LiveComponent.MatchLogistics do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("_logistics.html", assigns)
  end
end
