defmodule FraytElixir.CustomContracts.AAFESTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.AAFES
  alias FraytElixir.Shipment.MatchFee

  describe "calculate_pricing" do
    defp build_match(distance, weight, pieces, origin_state \\ "AL"),
      do:
        insert(:match,
          total_weight: weight,
          total_distance: distance,
          service_level: 2,
          vehicle_class: 1,
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
      match = build_match(5, 10, 3)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> AAFES.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %MatchFee{type: :base_fee, amount: 1340, driver_amount: 936}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
