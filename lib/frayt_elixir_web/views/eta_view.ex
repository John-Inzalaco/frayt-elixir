defmodule FraytElixirWeb.ETAView do
  use FraytElixirWeb, :view

  alias FraytElixir.Shipment.ETA

  def render("eta.json", %{eta: %ETA{id: id, arrive_at: arrive_at}}) do
    %{"id" => id, "arrive_at" => arrive_at}
  end

  def render("eta.json", _), do: nil
end
