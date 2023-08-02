defmodule FraytElixir.CustomContracts.TileShopStandardTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.TileShopStandard

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

      assert %Changeset{valid?: true} = changeset = TileShopStandard.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [%{type: :base_fee, amount: 23_00, driver_amount: 16_28}]
             } = Changeset.apply_changes(changeset)
    end

    test "with preferred_driver_fee" do
      driver = insert(:driver)
      match = insert(:match, preferred_driver: driver, platform: :deliver_pro)

      assert %Changeset{valid?: true} = changeset = TileShopStandard.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{
                   type: :base_fee,
                   amount: 3000,
                   driver_amount: 2133
                 },
                 %{
                   type: :preferred_driver_fee,
                   amount: 150,
                   driver_amount: 75
                 }
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
