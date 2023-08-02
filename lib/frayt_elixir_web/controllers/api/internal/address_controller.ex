defmodule FraytElixirWeb.API.Internal.AddressController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Shipment

  import FraytElixirWeb.SessionHelper, only: [authorize_shipper: 2]

  plug :authorize_shipper

  action_fallback FraytElixirWeb.FallbackController

  def index(%{assigns: %{current_shipper: shipper}} = conn, _params) do
    recent_addresses = Shipment.get_recent_addresses(shipper)
    render(conn, "index.json", addresses: recent_addresses)
  end
end
