defmodule FraytElixir.CustomContracts.SherwinDashTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.SherwinDash

  describe "calculate_pricing" do
    test "with proper parameters" do
      match = insert(:match, vehicle_class: 1, match_stops: [build(:match_stop, distance: 5)])

      assert %Changeset{valid?: true} = changeset = SherwinDash.calculate_pricing(match)

      assert %{
               driver_cut: 0.8,
               fees: [
                 %{type: :base_fee, amount: 2250, driver_amount: 1704}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
