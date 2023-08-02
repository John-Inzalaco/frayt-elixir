defmodule FraytElixir.CustomContracts.OPLTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.OPL

  describe "calculate_pricing" do
    test "with proper parameters" do
      match =
        insert(:match, vehicle_class: 3, match_stops: build_list(5, :match_stop, distance: 5))

      assert %Changeset{valid?: true} = changeset = OPL.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 9625, driver_amount: 6908}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
