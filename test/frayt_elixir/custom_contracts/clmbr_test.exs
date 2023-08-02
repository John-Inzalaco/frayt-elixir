defmodule FraytElixir.CustomContracts.ClmbrTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Clmbr

  describe "calculate_pricing" do
    defp build_match(distance, weight),
      do:
        insert(:match,
          total_weight: weight,
          total_distance: distance,
          fees: [],
          match_stops: [
            build(:match_stop,
              distance: distance,
              has_load_fee: true,
              items: [build(:match_stop_item, weight: weight, pieces: 1)]
            )
          ]
        )

    test "with proper parameters" do
      match = build_match(15, 25)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Clmbr.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 150_00, driver_amount: 107_85}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
