defmodule FraytElixirWeb.MatchSLAViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.MatchSLAView

  import FraytElixir.Factory

  test "rendered match SLA returns correct values" do
    %{
      start_time: start_time,
      end_time: end_time,
      completed_at: completed_at
    } = match_sla = insert(:match_sla, type: :pickup)

    assert %{
             type: :pickup,
             start_time: ^start_time,
             end_time: ^end_time,
             completed_at: ^completed_at
           } = MatchSLAView.render("match_sla.json", %{match_sla: match_sla})
  end
end
