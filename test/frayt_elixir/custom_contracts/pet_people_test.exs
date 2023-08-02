defmodule FraytElixir.CustomContracts.PetPeopleTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.PetPeople

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
               |> PetPeople.calculate_pricing()

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 2500, driver_amount: 1772}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
