defmodule FraytElixirWeb.LiveComponent.AdminEditShipper do
  use Phoenix.LiveComponent

  def render(assigns) do
    FraytElixirWeb.Admin.ShippersView.render("edit_shipper.html", assigns)
  end
end
