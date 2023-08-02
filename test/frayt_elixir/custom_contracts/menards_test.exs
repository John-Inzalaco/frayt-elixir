defmodule FraytElixir.CustomContracts.MenardsTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Menards

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
      match = build_match(21, 25)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Menards.calculate_pricing()

      assert %{
               driver_cut: 0.8,
               fees: [
                 %{type: :base_fee, amount: 3000, driver_amount: 2283}
               ]
             } =
               changeset
               |> Changeset.apply_changes()
    end

    test "with weight above 300 adds additonal fees on top" do
      match = build_match(21, 501)

      assert %Changeset{valid?: true} =
               changeset =
               match
               |> Menards.calculate_pricing()

      assert %{
               fees: [%{type: :base_fee, amount: 7000, driver_amount: 5367}],
               driver_cut: 0.8
             } =
               changeset
               |> Changeset.apply_changes()
    end
  end
end
