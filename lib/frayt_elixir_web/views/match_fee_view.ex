defmodule FraytElixirWeb.MatchFeeView do
  use FraytElixirWeb, :view
  alias FraytElixir.Shipment.MatchFeeType

  def render("shipper_match_fee.json", %{
        match_fee: %{
          id: id,
          amount: amount,
          description: description,
          type: type
        }
      }),
      do: %{
        id: id,
        amount: amount,
        description: description,
        type: type,
        name: MatchFeeType.name(type)
      }

  def render("driver_match_fee.json", %{
        match_fee: %{
          id: id,
          driver_amount: amount,
          description: description,
          type: type
        }
      }),
      do: %{
        id: id,
        amount: amount,
        description: description,
        type: type,
        name: MatchFeeType.name(type)
      }
end
