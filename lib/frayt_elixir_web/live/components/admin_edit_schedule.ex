defmodule FraytElixirWeb.LiveComponent.AdminEditSchedule do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("edit_schedule.html", assigns)
  end
end
