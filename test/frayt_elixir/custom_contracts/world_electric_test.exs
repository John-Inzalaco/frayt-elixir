defmodule FraytElixir.CustomContracts.WorldElectricTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.WorldElectric
  alias FraytElixir.Shipment.MatchFee

  describe "calculate_pricing" do
    defp build_match(distance, weight, pieces, origin_state \\ "AL"),
      do:
        insert(:match,
          total_weight: weight,
          total_distance: distance,
          origin_address: insert(:address, state_code: origin_state),
          fees: [],
          match_stops: [
            build(:match_stop,
              has_load_fee: true,
              distance: distance,
              items: [build(:match_stop_item, weight: ceil(weight / pieces), pieces: pieces)]
            )
          ]
        )

    test "with proper parameters" do
      match = build_match(9, 25, 1)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> WorldElectric.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %MatchFee{type: :base_fee, amount: 1900, driver_amount: 1339}
               ],
               match_stops: [
                 %{base_price: 1900, tip_price: 0, driver_cut: 0.75}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
