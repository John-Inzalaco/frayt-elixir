defmodule FraytElixir.CustomContracts.TBCTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.TBC

  describe "calculate_pricing" do
    defp build_match(distance, weight, pieces, origin_state \\ "OH"),
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
      match = build_match(35, 25, 1)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> TBC.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [%{type: :base_fee, amount: 3000, driver_amount: 2133}]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
