defmodule FraytElixirWeb.LiveComponent.AdminEditLocation do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("edit_location.html", assigns)
  end
end
