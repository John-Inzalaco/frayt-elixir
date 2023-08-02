defmodule FraytElixir.CustomContracts.LowesTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Lowes

  describe "calculate_pricing" do
    test "with proper parameters" do
      match =
        insert(:match,
          service_level: 1,
          total_weight: 15,
          match_stops: [
            build(:match_stop,
              distance: 16,
              items: [
                build(:match_stop_item,
                  width: 95,
                  length: 48,
                  height: 52,
                  pieces: 10,
                  weight: 5,
                  type: :lumber
                ),
                build(:match_stop_item,
                  width: 90,
                  length: 15,
                  height: 40,
                  pieces: 10,
                  weight: 5,
                  type: :sheet_rock
                ),
                build(:match_stop_item, width: 30, length: 12, height: 52, pieces: 1, weight: 5)
              ]
            )
          ]
        )

      assert %Changeset{valid?: true} = changeset = Lowes.calculate_pricing(match)

      assert %{
               driver_cut: 0.82,
               fees: [
                 %{type: :base_fee, amount: 3600},
                 %{type: :handling_fee, amount: 1250}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
