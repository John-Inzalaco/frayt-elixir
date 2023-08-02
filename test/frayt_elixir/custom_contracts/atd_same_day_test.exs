defmodule FraytElixir.CustomContracts.ATDSameDayTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.ATDSameDay
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
      match = build_match(21, 25, 3)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> ATDSameDay.calculate_pricing()

      assert %{
               driver_cut: 0.8,
               fees: [
                 %MatchFee{type: :base_fee, amount: 2600, driver_amount: 1974}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
