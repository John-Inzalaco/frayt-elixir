defmodule FraytElixirWeb.LiveComponent.AdminEditCompany do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("edit_company.html", assigns)
  end
end
