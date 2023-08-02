defmodule FraytElixir.CustomContracts.ZeitlinsTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Zeitlins
  alias FraytElixir.Shipment.MatchFee

  describe "calculate_pricing" do
    defp build_match(distance, weight, pieces),
      do:
        insert(:match,
          total_weight: weight,
          total_distance: distance,
          origin_address: insert(:address),
          fees: [],
          match_stops: [
            build(:match_stop,
              has_load_fee: true,
              distance: distance,
              items: [build(:match_stop_item, weight: ceil(weight / pieces), pieces: pieces)]
            )
          ]
        )

    test "with proper parameters regardless of the distance, weight or pieces `base_price` is always the same" do
      match = build_match(1, 25, 1)
      same_price_assert(match)

      match = build_match(100, 250, 1)
      same_price_assert(match)

      match = build_match(9000, 500, 10)
      same_price_assert(match)
    end

    defp same_price_assert(match) do
      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Zeitlins.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %MatchFee{type: :base_fee, amount: 3500, driver_amount: 2493}
               ],
               match_stops: [
                 %{base_price: 3500, tip_price: 0, driver_cut: 0.75}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
