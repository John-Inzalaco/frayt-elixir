defmodule FraytElixirWeb.API.V2x2.MatchView do
  use FraytElixirWeb, :view

  def render("show.json", %{match: match}) do
    response =
      match
      |> render_one(FraytElixirWeb.API.Internal.MatchView, "match.json")
      |> Map.delete(:shipper)

    %{response: response}
  end
end
