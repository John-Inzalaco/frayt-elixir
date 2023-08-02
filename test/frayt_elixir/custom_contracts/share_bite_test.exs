defmodule FraytElixir.CustomContracts.ShareBiteTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.ShareBite

  describe "calculate_pricing" do
    test "with proper parameters" do
      match = insert(:match, match_stops: [build(:match_stop, distance: 5, index: 0)])

      assert %Changeset{valid?: true} = changeset = ShareBite.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 3000, driver_amount: 2133}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
