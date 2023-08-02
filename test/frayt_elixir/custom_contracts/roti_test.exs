defmodule FraytElixir.CustomContracts.RotiTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.CustomContracts.Roti

  describe "calculate_pricing" do
    test "with proper parameters" do
      match =
        insert(:match,
          vehicle_class: 1,
          total_weight: 20,
          match_stops: [build(:match_stop, distance: 5, index: 0)]
        )

      assert %Changeset{valid?: true} = changeset = Roti.calculate_pricing(match)

      assert %{
               driver_cut: 0.75,
               fees: [
                 %{type: :base_fee, amount: 2500, driver_amount: 1766},
                 %{type: :driver_tip, amount: 200, driver_amount: 200}
               ]
             } = Changeset.apply_changes(changeset)
    end
  end
end
