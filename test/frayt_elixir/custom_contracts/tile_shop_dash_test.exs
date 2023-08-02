defmodule FraytElixir.CustomContracts.TileShopDashTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.TileShopDash

  describe "calculate_pricing" do
    defp build_match(vehicle_class, distance),
      do:
        insert(:match,
          vehicle_class: vehicle_class,
          total_distance: distance,
          fees: [],
          origin_address: build(:address)
        )

    test "with proper parameters" do
      match = build_match(1, 10)

      assert %Changeset{valid?: true} = changeset = TileShopDash.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [%{type: :base_fee, amount: 25_00, driver_amount: 17_72}]
             } = Changeset.apply_changes(changeset)
    end
  end
end
