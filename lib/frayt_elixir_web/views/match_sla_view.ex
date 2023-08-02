defmodule FraytElixirWeb.MatchSLAView do
  use FraytElixirWeb, :view

  def render("match_sla.json", %{match_sla: sla}),
    do: Map.take(sla, [:type, :start_time, :end_time, :completed_at])
end
