defmodule FraytElixir.CustomContracts.PetPeopleSameDayTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.PetPeopleSameDay

  describe "calculate_pricing" do
    defp build_match(distance, weight),
      do:
        insert(:match,
          total_weight: weight,
          total_distance: distance,
          fees: [],
          match_stops: [
            build(:match_stop,
              has_load_fee: true,
              distance: distance,
              items: [build(:match_stop_item, weight: weight, pieces: 1)]
            )
          ]
        )

    test "with proper parameters" do
      match = build_match(7, 25)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> PetPeopleSameDay.calculate_pricing()

      assert %{
               driver_cut: 0.8,
               fees: [
                 %{type: :base_fee, amount: 1900, driver_amount: 1434}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
