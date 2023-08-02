defmodule FraytElixirWeb.API.Internal.AddressView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.AddressView

  def render(layout, attrs), do: AddressView.render(layout, attrs)
end
