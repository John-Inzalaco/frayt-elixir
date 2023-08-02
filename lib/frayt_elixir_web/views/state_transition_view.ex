defmodule FraytElixirWeb.StateTransitionView do
  use FraytElixirWeb, :view

  def render("state_transition.json", %{
        state_transition: %{
          notes: notes,
          updated_at: updated_at,
          from: from,
          to: to
        }
      }) do
    %{
      notes: notes,
      updated_at: updated_at,
      from: from,
      to: to
    }
  end
end
