defmodule FraytElixirWeb.LiveComponent.MatchPickup do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("_pickup.html", assigns)
  end
end
