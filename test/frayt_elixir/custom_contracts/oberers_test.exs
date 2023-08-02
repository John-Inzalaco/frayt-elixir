defmodule FraytElixir.CustomContracts.OberersTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Oberers

  describe "calculate_pricing" do
    test "with proper parameters" do
      match =
        insert(:match, vehicle_class: 1, match_stops: build_list(5, :match_stop, distance: 5))

      assert %Changeset{valid?: true} = changeset = Oberers.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 6000, driver_amount: 4296}
               ]
             } = Changeset.apply_changes(changeset)
    end

    test "falls back to default pricing when less than 5 stops" do
      match =
        insert(:match,
          vehicle_class: 1,
          match_stops: Enum.map(0..3, &build(:match_stop, distance: 5, index: &1))
        )

      assert %Changeset{valid?: true} = changeset = Oberers.calculate_pricing(match)

      assert %{
               driver_cut: 0.72,
               fees: [
                 %{type: :base_fee, amount: 8188, driver_amount: 5626},
                 %{type: :route_surcharge, amount: 50, driver_amount: 0}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
