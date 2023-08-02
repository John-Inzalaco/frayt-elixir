defmodule FraytElixir.CustomContracts.TileShopSameDayTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.TileShopSameDay

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

      assert %Changeset{valid?: true} = changeset = TileShopSameDay.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [%{type: :base_fee, amount: 20_00, driver_amount: 14_12}]
             } = Changeset.apply_changes(changeset)
    end
  end
end
