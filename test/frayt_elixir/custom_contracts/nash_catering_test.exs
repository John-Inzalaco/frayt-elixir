defmodule FraytElixir.CustomContracts.NashCateringTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.NashCatering

  describe "calculate_pricing" do
    test "with proper parameters" do
      match =
        insert(:match,
          match_stops: [
            insert(:match_stop, distance: 10, index: 0),
            insert(:match_stop, distance: 10, index: 1),
            insert(:match_stop, distance: 10, index: 2)
          ]
        )

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> NashCatering.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               driver_fees: 233,
               fees: [
                 %{type: :base_fee, amount: 7000, driver_amount: 5017}
               ],
               match_stops: [
                 %{base_price: 3000, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 2000, tip_price: 0, driver_cut: 0.75},
                 %{base_price: 2000, tip_price: 0, driver_cut: 0.75}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
