defmodule FraytElixirWeb.API.Internal.NpsScoreView do
  use FraytElixirWeb, :view

  def render("feedback.json", %{score: score, feedback: feedback}) do
    %{
      score: score,
      feedback: feedback
    }
  end
end
