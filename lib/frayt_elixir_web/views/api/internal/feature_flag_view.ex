defmodule FraytElixirWeb.API.Internal.FeatureFlagView do
  use FraytElixirWeb, :view

  def render("show.json", %{enabled: enabled}) do
    %{enabled: enabled}
  end
end
