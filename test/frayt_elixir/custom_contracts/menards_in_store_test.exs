defmodule FraytElixir.CustomContracts.MenardsInStoreTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.MenardsInStore

  describe "calculate_pricing" do
    defp build_match(distance),
      do:
        insert(:match,
          total_distance: distance,
          fees: [],
          match_stops: [
            build(:match_stop, distance: distance)
          ]
        )

    test "with proper parameters" do
      match = build_match(14)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> MenardsInStore.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 69_00, driver_amount: 49_44}
               ],
               match_stops: [%{base_price: 69_00, tip_price: 0}]
             } =
               changeset
               |> Changeset.apply_changes()
    end

    test "over 35 miles" do
      match = build_match(37)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> MenardsInStore.calculate_pricing()

      assert %{
               fees: [
                 %{type: :base_fee, amount: 113_00, driver_amount: 81_17}
               ],
               driver_cut: 0.75,
               match_stops: [%{base_price: 113_00, tip_price: 0}]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
